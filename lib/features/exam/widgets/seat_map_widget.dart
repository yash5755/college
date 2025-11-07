import 'package:flutter/material.dart';

class SeatMapWidget extends StatelessWidget {
  final String roomName;
  final int rows;
  final int seatsPerRow;
  final Map<String, String> seatAssignments; // seat_key -> student_name
  final Map<String, String>? seatUSNs; // seat_key -> usn

  const SeatMapWidget({
    super.key,
    required this.roomName,
    required this.rows,
    required this.seatsPerRow,
    required this.seatAssignments,
    this.seatUSNs,
  });

  String _getSeatKey(int row, int seat) {
    return 'R${row.toString().padLeft(2, '0')}S${seat.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Layout: $rows rows × $seatsPerRow seats',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            // Stage/Board indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'STAGE / BOARD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Seat map
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(rows, (rowIdx) {
                    final rowNum = rows - rowIdx; // Start from back
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Row label
                          SizedBox(
                            width: 40,
                            child: Text(
                              'R$rowNum',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Seats
                          ...List.generate(seatsPerRow, (seatIdx) {
                            final seatNum = seatIdx + 1;
                            final seatKey = _getSeatKey(rowNum, seatNum);
                            final studentName = seatAssignments[seatKey];
                            final usn = seatUSNs?[seatKey];
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 60,
                              height: 50,
                              decoration: BoxDecoration(
                                color: studentName != null
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                border: Border.all(
                                  color: studentName != null
                                      ? Colors.green
                                      : Colors.grey,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: studentName != null
                                  ? Tooltip(
                                      message: '$studentName${usn != null ? '\n$usn' : ''}',
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            seatNum.toString(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (studentName != null)
                                            Text(
                                              studentName.length > 8
                                                  ? '${studentName.substring(0, 8)}...'
                                                  : studentName,
                                              style: const TextStyle(
                                                fontSize: 8,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        seatNum.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

