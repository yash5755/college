import 'package:flutter/material.dart';
import '../../../core/supabase_client.dart';

class RoomSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableRooms;
  final List<String>? selectedRoomIds;
  final Function(List<String>, Map<String, Map<String, dynamic>>) onConfirm;

  const RoomSelectionDialog({
    super.key,
    required this.availableRooms,
    this.selectedRoomIds,
    required this.onConfirm,
  });

  @override
  State<RoomSelectionDialog> createState() => _RoomSelectionDialogState();
}

class _RoomSelectionDialogState extends State<RoomSelectionDialog> {
  final Set<String> _selectedRoomIds = {};
  final Map<String, Map<String, dynamic>> _roomLayouts = {};

  @override
  void initState() {
    super.initState();
    if (widget.selectedRoomIds != null) {
      _selectedRoomIds.addAll(widget.selectedRoomIds!);
    }
    // Load existing room layouts
    _loadRoomLayouts();
  }

  Future<void> _loadRoomLayouts() async {
    for (final room in widget.availableRooms) {
      final roomId = room['id'].toString();
      final rows = room['rows_count'] as int?;
      final seatsPerRow = room['seats_per_row'] as int?;
      
      if (rows != null && seatsPerRow != null) {
        _roomLayouts[roomId] = {
          'rows': rows,
          'seats_per_row': seatsPerRow,
        };
      }
    }
    setState(() {});
  }

  Future<void> _configureRoomLayout(String roomId, Map<String, dynamic> room) async {
    final currentLayout = _roomLayouts[roomId];
    final rowsCtrl = TextEditingController(
      text: (currentLayout?['rows'] ?? room['rows_count'] ?? '').toString(),
    );
    final seatsPerRowCtrl = TextEditingController(
      text: (currentLayout?['seats_per_row'] ?? room['seats_per_row'] ?? '').toString(),
    );

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Configure Layout: ${room['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rowsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Rows/Benches',
                hintText: 'e.g., 10',
                prefixIcon: Icon(Icons.view_agenda),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: seatsPerRowCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seats per Row',
                hintText: 'e.g., 5',
                prefixIcon: Icon(Icons.chair),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final rows = int.tryParse(rowsCtrl.text.trim());
              final seatsPerRow = int.tryParse(seatsPerRowCtrl.text.trim());
              
              if (rows != null && rows > 0 && seatsPerRow != null && seatsPerRow > 0) {
                Navigator.of(ctx).pop({
                  'rows': rows,
                  'seats_per_row': seatsPerRow,
                });
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid numbers'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _roomLayouts[roomId] = result;
      });
      
      // Save to database
      try {
        await supabase.from('rooms').update({
          'rows_count': result['rows'],
          'seats_per_row': result['seats_per_row'],
        }).eq('id', roomId);
      } catch (e) {
        debugPrint('Error saving room layout: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Select Rooms'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.availableRooms.length,
                itemBuilder: (ctx, idx) {
                  final room = widget.availableRooms[idx];
                  final roomId = room['id'].toString();
                  final isSelected = _selectedRoomIds.contains(roomId);
                  final layout = _roomLayouts[roomId];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedRoomIds.add(roomId);
                          } else {
                            _selectedRoomIds.remove(roomId);
                          }
                        });
                      },
                      title: Text(room['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Capacity: ${room['capacity'] ?? 'N/A'}'),
                          if (layout != null)
                            Text(
                              'Layout: ${layout['rows']} rows × ${layout['seats_per_row']} seats',
                              style: const TextStyle(color: Colors.green),
                            )
                          else
                            const Text(
                              'Layout not configured',
                              style: TextStyle(color: Colors.orange),
                            ),
                        ],
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _configureRoomLayout(roomId, room),
                        tooltip: 'Configure Layout',
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedRoomIds.isEmpty
                        ? null
                        : () {
                            widget.onConfirm(
                              _selectedRoomIds.toList(),
                              _roomLayouts,
                            );
                            Navigator.of(context).pop();
                          },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

