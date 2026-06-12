package com.example.nero

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.math.abs

class NativeToolRuntime(
    private val context: Context,
) {
    fun execute(
        jobId: String,
        toolType: String,
        parameters: Map<String, Any?>,
    ): List<Map<String, Any?>> {
        val jobDirectory = resolveJobDirectory(jobId, parameters)
        val artifactsDirectory = File(jobDirectory, "artifacts").apply { mkdirs() }

        return when (toolType) {
            "generate_docx" -> listOf(generateDocx(jobId, artifactsDirectory, parameters))
            "generate_report_pdf" -> listOf(generatePdf(jobId, artifactsDirectory, parameters))
            "generate_xlsx" -> listOf(generateXlsx(jobId, artifactsDirectory, parameters))
            else ->
                throw IllegalArgumentException("Unsupported native tool type: $toolType")
        }
    }

    fun resolveJobDirectory(
        jobId: String,
        parameters: Map<String, Any?>,
    ): File {
        val explicitJobDir = parameters["jobDir"]?.toString()?.trim()
        val directory =
            if (!explicitJobDir.isNullOrEmpty()) {
                File(explicitJobDir)
            } else {
                File(context.filesDir, "tool_runtime${File.separator}jobs${File.separator}$jobId")
            }
        if (!directory.exists()) {
            directory.mkdirs()
        }
        return directory
    }

    private fun generateDocx(
        jobId: String,
        artifactsDirectory: File,
        parameters: Map<String, Any?>,
    ): Map<String, Any?> {
        val request = parameters.mapValue("request")
        val title = request.stringValue("title") ?: parameters.stringValue("title") ?: "Nero Document"
        val outputFile = File(artifactsDirectory, buildFileName(title, "docx"))

        ZipOutputStream(FileOutputStream(outputFile)).use { zip ->
            writeZipEntry(zip, "[Content_Types].xml", contentTypesXml())
            writeZipEntry(zip, "_rels/.rels", rootRelsXml())
            writeZipEntry(zip, "docProps/app.xml", appPropsXml())
            writeZipEntry(zip, "docProps/core.xml", corePropsXml(title))
            writeZipEntry(zip, "word/styles.xml", stylesXml())
            writeZipEntry(zip, "word/numbering.xml", numberingXml())
            writeZipEntry(zip, "word/document.xml", documentXml(request, title))
        }

        return buildArtifactDescriptor(
            jobId = jobId,
            toolType = "generate_docx",
            file = outputFile,
            kindLabel = "Word Document",
            mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        )
    }

    private fun generatePdf(
        jobId: String,
        artifactsDirectory: File,
        parameters: Map<String, Any?>,
    ): Map<String, Any?> {
        val request = parameters.mapValue("request")
        val title = request.stringValue("title") ?: parameters.stringValue("title") ?: "Nero PDF"
        val outputFile = File(artifactsDirectory, buildFileName(title, "pdf"))
        val pageSpec = resolvePdfPageSpec(request.mapValue("pageSettings"))
        val lines = buildPdfLines(title, request, parameters)

        val pdfDocument = PdfDocument()
        val titlePaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 18f
                isFakeBoldText = true
            }
        val textPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 11f
            }
        val footerPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.LTGRAY
                textSize = 9f
            }

        val left = pageSpec.marginLeft.toFloat()
        val top = pageSpec.marginTop.toFloat()
        val right = (pageSpec.width - pageSpec.marginRight).toFloat()
        val bottom = (pageSpec.height - pageSpec.marginBottom).toFloat()
        val contentWidth = right - left
        val titleHeight = abs(titlePaint.fontMetrics.ascent) + titlePaint.fontMetrics.descent
        val lineHeight = abs(textPaint.fontMetrics.ascent) + textPaint.fontMetrics.descent + 8f
        val footerHeight = abs(footerPaint.fontMetrics.ascent) + footerPaint.fontMetrics.descent

        var pageNumber = 1
        var page = pdfDocument.startPage(PdfDocument.PageInfo.Builder(pageSpec.width, pageSpec.height, pageNumber).create())
        var canvas = page.canvas
        var y = top

        fun drawFooter(targetCanvas: android.graphics.Canvas, targetPageNumber: Int) {
            targetCanvas.drawText(
                "Page $targetPageNumber",
                left,
                (pageSpec.height - (pageSpec.marginBottom / 2f)).toFloat(),
                footerPaint,
            )
        }

        fun startNewPage() {
            drawFooter(canvas, pageNumber)
            pdfDocument.finishPage(page)
            pageNumber += 1
            page =
                pdfDocument.startPage(
                    PdfDocument.PageInfo.Builder(pageSpec.width, pageSpec.height, pageNumber).create(),
                )
            canvas = page.canvas
            y = top
        }

        canvas.drawText(title, left, y + titleHeight, titlePaint)
        y += titleHeight + 18f

        for (line in lines) {
            val wrappedLines = wrapText(line, textPaint, contentWidth)
            for (wrapped in wrappedLines) {
                if (y + lineHeight > bottom - footerHeight - 12f) {
                    startNewPage()
                }
                canvas.drawText(wrapped, left, y, textPaint)
                y += lineHeight
            }
        }

        drawFooter(canvas, pageNumber)
        pdfDocument.finishPage(page)
        FileOutputStream(outputFile).use(pdfDocument::writeTo)
        pdfDocument.close()

        return buildArtifactDescriptor(
            jobId = jobId,
            toolType = "generate_report_pdf",
            file = outputFile,
            kindLabel = "PDF Document",
            mimeType = "application/pdf",
        )
    }

    private fun generateXlsx(
        jobId: String,
        artifactsDirectory: File,
        parameters: Map<String, Any?>,
    ): Map<String, Any?> {
        val workbook = parameters.mapValue("workbook")
        val title = workbook.stringValue("title") ?: parameters.stringValue("title") ?: "Nero Workbook"
        val outputFile = File(artifactsDirectory, buildFileName(title, "xlsx"))
        val rawSheets = workbook.listValue("sheets")
        val sheets =
            if (rawSheets.isEmpty()) {
                listOf(
                    mapOf(
                        "name" to "Sheet1",
                        "rows" to listOf(listOf("Title", title)),
                    ),
                )
            } else {
                rawSheets
            }

        ZipOutputStream(FileOutputStream(outputFile)).use { zip ->
            writeZipEntry(zip, "[Content_Types].xml", xlsxContentTypesXml(sheets.size))
            writeZipEntry(zip, "_rels/.rels", xlsxRootRelsXml())
            writeZipEntry(zip, "docProps/app.xml", xlsxAppPropsXml(sheets))
            writeZipEntry(zip, "docProps/core.xml", corePropsXml(title))
            writeZipEntry(zip, "xl/workbook.xml", workbookXml(sheets))
            writeZipEntry(zip, "xl/_rels/workbook.xml.rels", workbookRelsXml(sheets.size))
            writeZipEntry(zip, "xl/styles.xml", workbookStylesXml())
            for ((index, rawSheet) in sheets.withIndex()) {
                val sheet = rawSheet as? Map<*, *> ?: emptyMap<String, Any?>()
                writeZipEntry(
                    zip,
                    "xl/worksheets/sheet${index + 1}.xml",
                    worksheetXml(sheet),
                )
            }
        }

        return buildArtifactDescriptor(
            jobId = jobId,
            toolType = "generate_xlsx",
            file = outputFile,
            kindLabel = "Spreadsheet",
            mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    }

    private fun documentXml(
        request: Map<*, *>,
        title: String,
    ): String {
        val blocks = request.listValue("blocks")
        val buffer = StringBuilder()
        buffer.append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""")
        buffer.append(
            """<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>""",
        )

        if (blocks.isEmpty()) {
            buffer.append(paragraphXml(title, style = "Heading1"))
        }

        for (rawBlock in blocks) {
            val block = rawBlock as? Map<*, *> ?: continue
            when (block.stringValue("type")) {
                "heading" -> {
                    val level = (block.numberValue("level")?.toInt() ?: 1).coerceIn(1, 3)
                    buffer.append(paragraphXml(block.stringValue("text").orEmpty(), style = "Heading$level"))
                }
                "paragraph" -> buffer.append(paragraphXml(block.stringValue("text").orEmpty()))
                "bulletList" ->
                    block.listValue("items").forEach { item ->
                        buffer.append(paragraphXml(item?.toString().orEmpty(), numId = 1))
                    }
                "numberedList" ->
                    block.listValue("items").forEach { item ->
                        buffer.append(paragraphXml(item?.toString().orEmpty(), numId = 2))
                    }
                "table" -> buffer.append(tableXml(block))
            }
        }

        buffer.append("""<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>""")
        buffer.append("""</w:body></w:document>""")
        return buffer.toString()
    }

    private fun paragraphXml(
        text: String,
        style: String? = null,
        numId: Int? = null,
    ): String {
        val pPr = StringBuilder()
        if (style != null || numId != null) {
            pPr.append("<w:pPr>")
            if (style != null) {
                pPr.append("""<w:pStyle w:val="$style"/>""")
            }
            if (numId != null) {
                pPr.append("""<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>""")
            }
            pPr.append("</w:pPr>")
        }

        val lines = text.replace("\r\n", "\n").replace('\r', '\n').split('\n')
        val runBody =
            lines.mapIndexed { index, line ->
                val prefix = if (index == 0) "" else "<w:br/>"
                """$prefix<w:t xml:space="preserve">${xml(line)}</w:t>"""
            }.joinToString("")
        return """<w:p>$pPr<w:r>$runBody</w:r></w:p>"""
    }

    private fun tableXml(block: Map<*, *>): String {
        val columnCount = (block.numberValue("columnCount")?.toInt() ?: 1).coerceAtLeast(1)
        val columnWidth = 9360 / columnCount
        val grid = (0 until columnCount).joinToString("") { """<w:gridCol w:w="$columnWidth"/>""" }
        val rows =
            block.listValue("rows").joinToString("") { rawRow ->
                val row = (rawRow as? List<*>) ?: emptyList<Any?>()
                val cells =
                    (0 until columnCount).joinToString("") { index ->
                        val text = row.getOrNull(index)?.toString().orEmpty()
                        """<w:tc><w:tcPr><w:tcW w:w="$columnWidth" w:type="dxa"/></w:tcPr>${paragraphXml(text)}</w:tc>"""
                    }
                """<w:tr>$cells</w:tr>"""
            }
        return """<w:tbl><w:tblPr><w:tblW w:w="9360" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:color="CCCCCC"/><w:insideH w:val="single" w:sz="4" w:color="CCCCCC"/><w:insideV w:val="single" w:sz="4" w:color="CCCCCC"/></w:tblBorders></w:tblPr><w:tblGrid>$grid</w:tblGrid>$rows</w:tbl>"""
    }

    private fun writeZipEntry(
        zip: ZipOutputStream,
        path: String,
        content: String,
    ) {
        val bytes = content.toByteArray(StandardCharsets.UTF_8)
        zip.putNextEntry(ZipEntry(path))
        zip.write(bytes)
        zip.closeEntry()
    }

    private fun contentTypesXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
          <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
        </Types>
        """.trimIndent()

    private fun rootRelsXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """.trimIndent()

    private fun appPropsXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
          xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>Nero</Application>
        </Properties>
        """.trimIndent()

    private fun corePropsXml(title: String): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
          xmlns:dc="http://purl.org/dc/elements/1.1/"
          xmlns:dcterms="http://purl.org/dc/terms/"
          xmlns:dcmitype="http://purl.org/dc/dcmitype/"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>${xml(title)}</dc:title>
          <dc:creator>Nero</dc:creator>
        </cp:coreProperties>
        """.trimIndent()

    private fun stylesXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
          <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
          <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
          <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
        </w:styles>
        """.trimIndent()

    private fun numberingXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl></w:abstractNum>
          <w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
          <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
          <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
        </w:numbering>
        """.trimIndent()

    private fun xlsxContentTypesXml(sheetCount: Int): String {
        val sheetOverrides =
            (1..sheetCount).joinToString("\n") { index ->
                """  <Override PartName="/xl/worksheets/sheet$index.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"""
            }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        $sheetOverrides
        </Types>
        """.trimIndent()
    }

    private fun xlsxRootRelsXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """.trimIndent()

    private fun xlsxAppPropsXml(sheets: List<*>): String {
        val parts =
            sheets.mapIndexed { index, rawSheet ->
                val sheet = rawSheet as? Map<*, *> ?: emptyMap<String, Any?>()
                """<vt:lpstr>${xml(sheet.stringValue("name") ?: "Sheet${index + 1}")}</vt:lpstr>"""
            }.joinToString("")
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
          xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>Nero</Application>
          <TitlesOfParts>
            <vt:vector size="${sheets.size}" baseType="lpstr">$parts</vt:vector>
          </TitlesOfParts>
        </Properties>
        """.trimIndent()
    }

    private fun workbookXml(sheets: List<*>): String {
        val sheetNodes =
            sheets.mapIndexed { index, rawSheet ->
                val sheet = rawSheet as? Map<*, *> ?: emptyMap<String, Any?>()
                val name = xml(sanitizeSheetName(sheet.stringValue("name") ?: "Sheet${index + 1}"))
                """<sheet name="$name" sheetId="${index + 1}" r:id="rId${index + 1}"/>"""
            }.joinToString("")
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>$sheetNodes</sheets>
        </workbook>
        """.trimIndent()
    }

    private fun workbookRelsXml(sheetCount: Int): String {
        val sheetRels =
            (1..sheetCount).joinToString("") { index ->
                """<Relationship Id="rId$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$index.xml"/>"""
            }
        val stylesId = sheetCount + 1
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          $sheetRels
          <Relationship Id="rId$stylesId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """.trimIndent()
    }

    private fun workbookStylesXml(): String =
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
          <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
          <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
          <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """.trimIndent()

    private fun worksheetXml(sheet: Map<*, *>): String {
        val rows = sheet.listValue("rows")
        val rowNodes =
            rows.mapIndexed { rowIndex, rawRow ->
                val row = rawRow as? List<*> ?: emptyList<Any?>()
                val cellNodes =
                    row.mapIndexed { columnIndex, value ->
                        worksheetCellXml(
                            rowIndex = rowIndex + 1,
                            columnIndex = columnIndex,
                            value = value,
                        )
                    }.joinToString("")
                """<row r="${rowIndex + 1}">$cellNodes</row>"""
            }.joinToString("")
        val dimensionRef =
            if (rows.isEmpty()) {
                "A1"
            } else {
                val lastColumn = maxRowWidth(rows).coerceAtLeast(1) - 1
                "A1:${columnName(lastColumn)}${rows.size}"
            }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="$dimensionRef"/>
          <sheetViews><sheetView workbookViewId="0"/></sheetViews>
          <sheetFormatPr defaultRowHeight="15"/>
          <sheetData>$rowNodes</sheetData>
        </worksheet>
        """.trimIndent()
    }

    private fun worksheetCellXml(
        rowIndex: Int,
        columnIndex: Int,
        value: Any?,
    ): String {
        val reference = "${columnName(columnIndex)}$rowIndex"
        return when (value) {
            null -> """<c r="$reference"/>"""
            is Number -> """<c r="$reference"><v>${value}</v></c>"""
            is Boolean -> """<c r="$reference" t="b"><v>${if (value) 1 else 0}</v></c>"""
            else -> {
                val text = value.toString()
                if (text.startsWith("=") && text.length > 1) {
                    """<c r="$reference"><f>${xml(text.removePrefix("="))}</f></c>"""
                } else {
                    """<c r="$reference" t="inlineStr"><is><t xml:space="preserve">${xml(text)}</t></is></c>"""
                }
            }
        }
    }

    private fun maxRowWidth(rows: List<*>): Int =
        rows.maxOfOrNull { rawRow -> (rawRow as? List<*>)?.size ?: 0 } ?: 0

    private fun columnName(columnIndex: Int): String {
        var index = columnIndex
        val name = StringBuilder()
        do {
            name.insert(0, ('A'.code + (index % 26)).toChar())
            index = (index / 26) - 1
        } while (index >= 0)
        return name.toString()
    }

    private fun resolvePdfPageSpec(pageSettings: Map<*, *>): PdfPageSpec {
        val orientation = pageSettings.stringValue("orientation") ?: "portrait"
        val paperSize = pageSettings.stringValue("paperSize") ?: "a4"
        val portrait =
            when (paperSize.lowercase()) {
                "letter", "us-letter" -> 612 to 792
                else -> 595 to 842
            }
        val dimensions =
            if (orientation.equals("landscape", ignoreCase = true)) {
                portrait.second to portrait.first
            } else {
                portrait
            }
        return PdfPageSpec(
            width = dimensions.first,
            height = dimensions.second,
            marginTop = pageSettings.numberValue("marginTop")?.toInt() ?: 48,
            marginBottom = pageSettings.numberValue("marginBottom")?.toInt() ?: 48,
            marginLeft = pageSettings.numberValue("marginLeft")?.toInt() ?: 48,
            marginRight = pageSettings.numberValue("marginRight")?.toInt() ?: 48,
        )
    }

    private fun buildPdfLines(
        title: String,
        request: Map<*, *>,
        parameters: Map<String, Any?>,
    ): List<String> {
        val lines = mutableListOf<String>()
        val blocks = request.listValue("blocks")
        for (rawBlock in blocks) {
            val block = rawBlock as? Map<*, *> ?: continue
            when (block.stringValue("type")) {
                "heading" -> lines += block.stringValue("text").orEmpty()
                "paragraph" -> lines += block.stringValue("text").orEmpty()
                "bulletList" ->
                    lines += block.listValue("items").map { item -> "• ${item?.toString().orEmpty()}" }
                "numberedList" ->
                    lines += block.listValue("items").mapIndexed { index, item ->
                        "${index + 1}. ${item?.toString().orEmpty()}"
                    }
                "table" -> {
                    for (row in block.listValue("rows")) {
                        val rowValues = (row as? List<*>)?.map { it?.toString().orEmpty() } ?: emptyList()
                        lines += rowValues.joinToString(" | ")
                    }
                }
            }
            lines += ""
        }
        val directContent = parameters["content"]?.toString()?.trim().orEmpty()
        if (lines.isEmpty() && directContent.isNotEmpty()) {
            lines += directContent.replace("\r\n", "\n").replace('\r', '\n').split('\n')
        }
        if (lines.isEmpty()) {
            lines += title
        }
        return lines
    }

    private fun wrapText(
        text: String,
        paint: Paint,
        maxWidth: Float,
    ): List<String> {
        if (text.isBlank()) {
            return listOf("")
        }
        val words = text.split(Regex("\\s+"))
        val lines = mutableListOf<String>()
        var current = StringBuilder()
        for (word in words) {
            val candidate = if (current.isEmpty()) word else "${current} $word"
            if (paint.measureText(candidate) <= maxWidth) {
                current = StringBuilder(candidate)
            } else {
                if (current.isNotEmpty()) {
                    lines += current.toString()
                }
                current = StringBuilder(word)
            }
        }
        if (current.isNotEmpty()) {
            lines += current.toString()
        }
        return if (lines.isEmpty()) listOf(text) else lines
    }

    private fun buildArtifactDescriptor(
        jobId: String,
        toolType: String,
        file: File,
        kindLabel: String,
        mimeType: String,
    ): Map<String, Any?> =
        mapOf(
            "id" to "artifact_${System.currentTimeMillis()}",
            "title" to file.name,
            "kindLabel" to kindLabel,
            "localPath" to file.absolutePath,
            "extension" to file.extension,
            "mimeType" to mimeType,
            "sizeBytes" to file.length(),
            "metadata" to
                mapOf(
                    "jobId" to jobId,
                    "toolType" to toolType,
                ),
        )

    private fun buildFileName(
        title: String,
        extension: String,
    ): String {
        val sanitized =
            title
                .replace(Regex("[\\\\/:*?\"<>|]+"), "")
                .replace(Regex("\\s+"), "_")
                .trim()
                .ifEmpty { "nero_document" }
        return if (sanitized.lowercase().endsWith(".$extension")) sanitized else "$sanitized.$extension"
    }

    private fun sanitizeSheetName(name: String): String =
        name
            .replace(Regex("[\\\\/?*\\[\\]:]+"), "_")
            .take(31)
            .ifBlank { "Sheet1" }

    private fun xml(value: String): String =
        value
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")

    private fun Map<*, *>.stringValue(key: String): String? = this[key]?.toString()?.trim()?.ifEmpty { null }

    private fun Map<*, *>.numberValue(key: String): Number? = this[key] as? Number

    private fun Map<*, *>.listValue(key: String): List<*> = this[key] as? List<*> ?: emptyList<Any?>()

    @Suppress("UNCHECKED_CAST")
    private fun Map<*, *>.mapValue(key: String): Map<*, *> = this[key] as? Map<*, *> ?: emptyMap<String, Any?>()
}

private data class PdfPageSpec(
    val width: Int,
    val height: Int,
    val marginTop: Int,
    val marginBottom: Int,
    val marginLeft: Int,
    val marginRight: Int,
)
