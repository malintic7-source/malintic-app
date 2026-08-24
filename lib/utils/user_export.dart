import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gestion_formations/Models/user.dart';

/// Exports selected users to CSV, clipboard, and the default mail client.
String usersToCsv(Iterable<User> users) {
  final buffer = StringBuffer();
  buffer.writeln('id,prenom,nom,email,phone,estActif');
  for (final user in users) {
    buffer.writeln(
      '${user.id},${user.prenom},${user.nom},${user.email},${user.phone},${user.estActif}',
    );
  }
  return buffer.toString();
}

/// Copies users to the clipboard using the shared CSV representation.
Future<void> copyUsersCsvToClipboard(Iterable<User> users) async {
  await Clipboard.setData(ClipboardData(text: usersToCsv(users)));
}

/// Opens a mailto URI for users with non-empty email addresses.
Future<bool> launchMailtoForUsers(Iterable<User> users) async {
  final emails = users.map((user) => user.email).where((email) => email.isNotEmpty).join(',');
  if (emails.isEmpty) return false;
  return launchUrl(Uri.parse('mailto:$emails'));
}
