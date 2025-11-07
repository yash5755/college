import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class SeatMapPdfService {
  static Future<File> generateSeatMapPdf({
    required String examName,
    required String examDate,
    required String examTime,
    required String roomName,
    required int rows,
    required int seatsPerRow,
    required Map<String, String> seatAssignments, // seat_key -> student_name
    Map<String, String>? seatUSNs, // seat_key -> usn
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        examName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: $examDate | Time: $examTime',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Text(
                    roomName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              
              // Stage indicator
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'STAGE / BOARD',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              
              // Seat map
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: List.generate(rows, (rowIdx) {
                    final rowNum = rows - rowIdx; // Start from back
                    return pw.TableRow(
                      children: [
                        // Row label
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          color: PdfColors.grey100,
                          child: pw.Center(
                            child: pw.Text(
                              'R$rowNum',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Seats
                        ...List.generate(seatsPerRow, (seatIdx) {
                          final seatNum = seatIdx + 1;
                          final seatKey = _getSeatKey(rowNum, seatNum);
                          final studentName = seatAssignments[seatKey];
                          final usn = seatUSNs?[seatKey];
                          
                          return pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            color: studentName != null
                                ? PdfColors.green100
                                : PdfColors.grey200,
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  seatNum.toString(),
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                if (studentName != null) ...[
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    studentName.length > 10
                                        ? '${studentName.substring(0, 10)}...'
                                        : studentName,
                                    style: const pw.TextStyle(fontSize: 7),
                                    textAlign: pw.TextAlign.center,
                                    maxLines: 1,
                                  ),
                                  if (usn != null) ...[
                                    pw.SizedBox(height: 1),
                                    pw.Text(
                                      usn,
                                      style: pw.TextStyle(
                                        fontSize: 6,
                                        color: PdfColors.grey700,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ),
              ),
              
              pw.SizedBox(height: 16),
              
              // Legend
              pw.Row(
                children: [
                  pw.Container(
                    width: 20,
                    height: 20,
                    color: PdfColors.green100,
                    margin: const pw.EdgeInsets.only(right: 8),
                  ),
                  pw.Text('Occupied', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 20),
                  pw.Container(
                    width: 20,
                    height: 20,
                    color: PdfColors.grey200,
                    margin: const pw.EdgeInsets.only(right: 8),
                  ),
                  pw.Text('Empty', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/seat_map_${roomName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }

  static String _getSeatKey(int row, int seat) {
    return 'R${row.toString().padLeft(2, '0')}S${seat.toString().padLeft(2, '0')}';
  }

  static Future<void> printPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  static Future<void> sharePdf(File pdfFile, BuildContext context) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
}

