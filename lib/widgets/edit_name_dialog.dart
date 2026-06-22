import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dialog kecil untuk edit nama. Mengelola TextEditingController-nya sendiri
/// (dispose saat route benar-benar hilang) dan HANYA mengembalikan teks via
/// Navigator.pop — tidak ada async/Firestore di sini, supaya tidak ada race
/// antara dispose controller dan animasi tutup dialog.
class EditNameDialog extends StatefulWidget {
  final String initialName;

  const EditNameDialog({super.key, required this.initialName});

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final TextEditingController _controller;

  static const Color _primaryBlue = Color(0xFF133D87);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Edit Nama',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
