import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final int initialRows;
  final int initialColumns;
  final int initialShelves;

  const SettingsPage({super.key, 
    required this.initialRows,
    required this.initialColumns,
    required this.initialShelves, required void Function(Map<String, int> settings) onSettingsUpdated,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController rowController;
  late TextEditingController colController;
  late TextEditingController shelfController;

  @override
  void initState() {
    super.initState();
    rowController = TextEditingController(text: widget.initialRows.toString());
    colController = TextEditingController(
      text: widget.initialColumns.toString(),
    );
    shelfController = TextEditingController(
      text: widget.initialShelves.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: rowController,
              decoration: InputDecoration(labelText: "Rows"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: colController,
              decoration: InputDecoration(labelText: "Columns"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: shelfController,
              decoration: InputDecoration(labelText: "Shelves"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'rows':
                      int.tryParse(rowController.text) ?? widget.initialRows,
                  'columns':
                      int.tryParse(colController.text) ?? widget.initialColumns,
                  'shelves':
                      int.tryParse(shelfController.text) ??
                      widget.initialShelves,
                });
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
