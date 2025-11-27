import 'dart:io';
import 'package:cl_server/cl_server.dart';

void main() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║   CL Server Client - Interactive CLI (Auth + Media Store)      ║');
  print('╚════════════════════════════════════════════════════════════════╝\n');

  // Parse command line arguments
  final authHost = _parseArg('--auth-host', 'localhost');
  final authPort = _parseArg('--auth-port', '8000');
  final mediaHost = _parseArg('--media-host', 'localhost');
  final mediaPort = _parseArg('--media-port', '8001');

  final authClient = AuthClient(baseUrl: 'http://$authHost:$authPort');
  final mediaStoreClient = MediaStoreClient(baseUrl: 'http://$mediaHost:$mediaPort');
  var currentToken = '';
  var currentUser = null;

  print('💡 Type "help" for available commands\n');

  try {
    while (true) {
      stdout.write('cl_server> ');
      final line = stdin.readLineSync();

      if (line == null || line.isEmpty) continue;

      final parts = line.trim().split(RegExp(r'\s+'));
      final command = parts[0].toLowerCase();
      final args = parts.skip(1).toList();

      try {
        switch (command) {
          case 'help':
            _printHelp();

          case 'login':
            if (args.length < 2) {
              print('❌ Usage: login <username> <password>');
              continue;
            }
            final token = await authClient.login(args[0], args[1]);
            currentToken = token.accessToken;
            final tokenData = authClient.parseToken(token.accessToken);
            currentUser = tokenData;
            print('✅ Login successful!');
            print('   User ID: ${tokenData.userId}');
            print('   Admin: ${tokenData.isAdmin}');
            print('   Permissions: ${tokenData.permissions.join(', ')}');
            print('   Expires: ${tokenData.expiresAt.toLocal()}');

          case 'whoami':
            if (currentToken.isEmpty) {
              print('❌ Not logged in. Use "login" command first.');
              continue;
            }
            final user = await authClient.getCurrentUser(currentToken);
            print('✅ Current User:');
            print('   ID: ${user.id}');
            print('   Username: ${user.username}');
            print('   Admin: ${user.isAdmin}');
            print('   Active: ${user.isActive}');
            print('   Created: ${user.createdAt.toLocal()}');
            print('   Permissions: ${user.permissions.join(', ')}');

          case 'logout':
            currentToken = '';
            currentUser = null;
            print('✅ Logged out');

          case 'token-info':
            if (currentToken.isEmpty) {
              print('❌ Not logged in');
              continue;
            }
            final tokenData = authClient.parseToken(currentToken);
            print('✅ Token Information:');
            print('   User ID: ${tokenData.userId}');
            print('   Admin: ${tokenData.isAdmin}');
            print('   Permissions: ${tokenData.permissions.join(', ')}');
            print('   Expired: ${tokenData.isExpired}');
            print('   Remaining: ${tokenData.remainingDuration.inMinutes} minutes');
            print('   Expires: ${tokenData.expiresAt.toLocal()}');

          case 'save-token':
            if (currentToken.isEmpty) {
              print('❌ Not logged in');
              continue;
            }
            if (args.isEmpty) {
              print('❌ Usage: save-token <filename>');
              continue;
            }
            final file = File(args[0]);
            await file.writeAsString(currentToken);
            print('✅ Token saved to ${args[0]}');

          case 'load-token':
            if (args.isEmpty) {
              print('❌ Usage: load-token <filename>');
              continue;
            }
            final file = File(args[0]);
            if (!await file.exists()) {
              print('❌ File not found: ${args[0]}');
              continue;
            }
            currentToken = await file.readAsString();
            final tokenData = authClient.parseToken(currentToken);
            currentUser = tokenData;
            if (tokenData.isExpired) {
              print('⚠️  Token has expired!');
            } else {
              print('✅ Token loaded from ${args[0]}');
              print('   Expires in: ${tokenData.remainingDuration.inMinutes} minutes');
            }

          case 'public-key':
            final publicKey = await authClient.getPublicKey();
            print('✅ Public Key:');
            print(publicKey);

          case 'users':
            if (args.isEmpty) {
              print('❌ Usage: users <list|get|create|update|delete>');
              continue;
            }
            if (currentToken.isEmpty) {
              print('❌ Not logged in');
              continue;
            }
            await _handleUsersCommand(authClient, currentToken, args);

          case 'media':
            if (args.isEmpty) {
              print('❌ Usage: media <list|get|create-collection|upload|patch|delete|versions|config-get|config-set>');
              continue;
            }
            if (currentToken.isEmpty) {
              print('❌ Not logged in');
              continue;
            }
            await _handleMediaCommand(mediaStoreClient, currentToken, args);

          case 'exit':
            print('\n👋 Goodbye!');
            authClient.close();
            mediaStoreClient.close();
            exit(0);

          default:
            print('❌ Unknown command: $command. Type "help" for available commands.');
        }
      } catch (e) {
        if (e is AuthenticationException) {
          print('❌ Authentication failed: ${e.message}');
        } else if (e is AuthorizationException) {
          print('❌ Access denied: ${e.message}');
        } else if (e is NotFoundException) {
          print('❌ Not found: ${e.message}');
        } else if (e is ValidationException) {
          print('❌ Validation error: ${e.message}');
        } else if (e is DuplicateResourceException) {
          print('❌ Duplicate: ${e.message}');
        } else if (e is ServerException) {
          print('❌ Server error: ${e.message}');
        } else if (e is CLServerException) {
          print('❌ Error: ${e.message}');
        } else {
          print('❌ Error: $e');
        }
      }
    }
  } finally {
    authClient.close();
    mediaStoreClient.close();
  }
}

void _printHelp() {
  print('''
AUTHENTICATION COMMANDS:
  login <username> <password>           - Login and get token
  whoami                                - Show current user info
  logout                                - Clear current session
  token-info                            - Display current token details
  save-token <file>                     - Save token to file
  load-token <file>                     - Load token from file
  public-key                            - Fetch public key

USER MANAGEMENT (Admin):
  users list [--skip N] [--limit N]     - List users
  users get <user_id>                   - Get user details
  users create <name> <pass> [--admin] [--perms P1,P2]  - Create user
  users update <id> [--pass P] [--admin] [--perms P1,P2] - Update user
  users delete <user_id>                - Delete user

MEDIA STORE COMMANDS (requires login):
  media list [--page N] [--size N]      - List media entities
  media get <id>                        - Get entity details
  media create-collection <name> [--desc DESC]  - Create collection
  media upload <filepath> [--name N] [--desc D] [--parent P]  - Upload file
  media patch <id> [--label L] [--desc D] [--parent P]  - Update entity
  media delete <id>                     - Delete entity
  media versions <id>                   - List all versions
  media config-get                      - Get service config (admin)
  media config-set <true|false>         - Set read auth requirement (admin)

GENERAL:
  help                                  - Show this help
  exit                                  - Exit CLI

EXAMPLES:
  > login admin admin
  > whoami
  > users create testuser password123 --perms read,write
  > users update 5 --admin
  > media list
  > media create-collection "My Files"
  > media upload /path/to/file.jpg --name "Vacation Photo"
  > logout
''');
}

Future<void> _handleMediaCommand(
  MediaStoreClient client,
  String token,
  List<String> args,
) async {
  final subcommand = args[0].toLowerCase();
  final subargs = args.skip(1).toList();

  switch (subcommand) {
    case 'list':
      final pageStr = _getArgValue(subargs, '--page', '1') ?? '1';
      final sizeStr = _getArgValue(subargs, '--size', '10') ?? '10';
      final page = int.tryParse(pageStr) ?? 1;
      final size = int.tryParse(sizeStr) ?? 10;
      final entities = await client.listEntities(
        token: token,
        page: page,
        pageSize: size,
      );
      print('✅ Entities (${entities.length} shown):');
      for (final entity in entities) {
        final type = entity.isCollection ? '📁' : '📄';
        print('   $type [${entity.id}] ${entity.label} (${entity.isDeleted == true ? 'deleted' : 'active'})');
      }

    case 'get':
      if (subargs.isEmpty) {
        print('❌ Usage: media get <entity_id>');
        return;
      }
      final entityId = int.tryParse(subargs[0]);
      if (entityId == null) {
        print('❌ Invalid entity ID');
        return;
      }
      final entity = await client.getEntity(token: token, entityId: entityId);
      print('✅ Entity Details:');
      print('   ID: ${entity.id}');
      print('   Label: ${entity.label}');
      print('   Type: ${entity.isCollection ? 'Collection' : 'File'}');
      print('   Size: ${entity.fileSize ?? 'N/A'} bytes');
      print('   MIME: ${entity.mimeType ?? 'N/A'}');
      print('   Deleted: ${entity.isDeleted == true ? 'Yes' : 'No'}');

    case 'create-collection':
      if (subargs.isEmpty) {
        print('❌ Usage: media create-collection <name> [--desc DESC]');
        return;
      }
      final name = subargs[0];
      final desc = _getArgValue(subargs, '--desc', null);
      final created = await client.createCollection(
        token: token,
        label: name,
        description: desc,
      );
      print('✅ Collection created: ID=${created.id}, Name=${created.label}');

    case 'upload':
      if (subargs.isEmpty) {
        print('❌ Usage: media upload <filepath> [--name NAME] [--desc DESC] [--parent PARENT_ID]');
        return;
      }
      final filepath = subargs[0];
      final file = File(filepath);
      if (!await file.exists()) {
        print('❌ File not found: $filepath');
        return;
      }
      final name = _getArgValue(subargs, '--name', null) ?? file.path.split('/').last;
      final desc = _getArgValue(subargs, '--desc', null);
      final parentStr = _getArgValue(subargs, '--parent', null);
      final parentId = parentStr != null ? int.tryParse(parentStr) : null;

      final uploaded = await client.createEntity(
        token: token,
        label: name,
        file: file,
        description: desc,
        parentId: parentId,
      );
      print('✅ File uploaded: ID=${uploaded.id}, Size=${uploaded.fileSize} bytes');

    case 'patch':
      if (subargs.isEmpty) {
        print('❌ Usage: media patch <entity_id> [--label LABEL] [--desc DESC] [--parent PARENT_ID]');
        return;
      }
      final entityId = int.tryParse(subargs[0]);
      if (entityId == null) {
        print('❌ Invalid entity ID');
        return;
      }
      final label = _getArgValue(subargs, '--label', null);
      final desc = _getArgValue(subargs, '--desc', null);
      final parentStr = _getArgValue(subargs, '--parent', null);
      final parentId = parentStr != null ? int.tryParse(parentStr) : null;

      final patched = await client.patchEntity(
        token: token,
        entityId: entityId,
        label: label,
        description: desc,
        parentId: parentId,
      );
      print('✅ Entity updated: ID=${patched.id}');

    case 'delete':
      if (subargs.isEmpty) {
        print('❌ Usage: media delete <entity_id>');
        return;
      }
      final entityId = int.tryParse(subargs[0]);
      if (entityId == null) {
        print('❌ Invalid entity ID');
        return;
      }
      await client.deleteEntity(token: token, entityId: entityId);
      print('✅ Entity deleted: ID=$entityId');

    case 'versions':
      if (subargs.isEmpty) {
        print('❌ Usage: media versions <entity_id>');
        return;
      }
      final entityId = int.tryParse(subargs[0]);
      if (entityId == null) {
        print('❌ Invalid entity ID');
        return;
      }
      final versions = await client.getVersions(token: token, entityId: entityId);
      print('✅ Versions (${versions.length} total):');
      for (int i = 0; i < versions.length; i++) {
        final v = versions[i];
        print('   [${i + 1}] ${v.label}');
      }

    case 'config-get':
      final config = await client.getConfig(token: token);
      print('✅ Config:');
      print('   Read Auth Enabled: ${config.readAuthEnabled}');
      print('   Updated: ${config.updatedAt ?? 'N/A'}');

    case 'config-set':
      if (subargs.isEmpty) {
        print('❌ Usage: media config-set <true|false>');
        return;
      }
      final enabled = subargs[0].toLowerCase() == 'true';
      final config = await client.setReadAuth(token: token, readAuthEnabled: enabled);
      print('✅ Config updated: read_auth_enabled=${config.readAuthEnabled}');

    default:
      print('❌ Unknown media subcommand: $subcommand');
  }
}

Future<void> _handleUsersCommand(
  AuthClient client,
  String token,
  List<String> args,
) async {
  final subcommand = args[0].toLowerCase();
  final subargs = args.skip(1).toList();

  switch (subcommand) {
    case 'list':
      final skipStr = _getArgValue(subargs, '--skip', '0') ?? '0';
      final limitStr = _getArgValue(subargs, '--limit', '100') ?? '100';
      final skip = int.tryParse(skipStr) ?? 0;
      final limit = int.tryParse(limitStr) ?? 100;
      final users = await client.listUsers(token: token, skip: skip, limit: limit);
      print('✅ Users (${users.length} shown):');
      for (final user in users) {
        print('   [${user.id}] ${user.username} (admin: ${user.isAdmin}, active: ${user.isActive})');
      }

    case 'get':
      if (subargs.isEmpty) {
        print('❌ Usage: users get <user_id>');
        return;
      }
      final userId = int.tryParse(subargs[0]);
      if (userId == null) {
        print('❌ Invalid user ID');
        return;
      }
      final user = await client.getUser(token: token, userId: userId);
      print('✅ User Details:');
      print('   ID: ${user.id}');
      print('   Username: ${user.username}');
      print('   Admin: ${user.isAdmin}');
      print('   Active: ${user.isActive}');
      print('   Created: ${user.createdAt.toLocal()}');
      print('   Permissions: ${user.permissions.join(', ')}');

    case 'create':
      if (subargs.isEmpty) {
        print('❌ Usage: users create <username> <password> [--admin] [--perms P1,P2]');
        return;
      }
      final username = subargs[0];
      final password = subargs.length > 1 ? subargs[1] : '';
      if (password.isEmpty) {
        print('❌ Usage: users create <username> <password> [--admin] [--perms P1,P2]');
        return;
      }
      final isAdmin = _hasArg(subargs, '--admin');
      final permsStr = _getArgValue(subargs, '--perms', '') ?? '';
      final permissions = permsStr.isEmpty ? <String>[] : permsStr.split(',');

      final user = await client.createUser(
        token: token,
        username: username,
        password: password,
        isAdmin: isAdmin,
        permissions: permissions,
      );
      print('✅ User created: ID=${user.id}, Username=${user.username}');

    case 'update':
      if (subargs.isEmpty) {
        print('❌ Usage: users update <user_id> [--pass P] [--admin true|false] [--perms P1,P2]');
        return;
      }
      final userId = int.tryParse(subargs[0]);
      if (userId == null) {
        print('❌ Invalid user ID');
        return;
      }
      final password = _getArgValue(subargs, '--pass', null);
      final adminStr = _getArgValue(subargs, '--admin', null);
      final isAdmin = adminStr != null ? adminStr.toLowerCase() == 'true' : null;
      final permsStr = _getArgValue(subargs, '--perms', null);
      final permissions = permsStr != null ? permsStr.split(',') : null;

      final user = await client.updateUser(
        token: token,
        userId: userId,
        password: password,
        isAdmin: isAdmin,
        permissions: permissions,
      );
      print('✅ User updated: ID=${user.id}');

    case 'delete':
      if (subargs.isEmpty) {
        print('❌ Usage: users delete <user_id>');
        return;
      }
      final userId = int.tryParse(subargs[0]);
      if (userId == null) {
        print('❌ Invalid user ID');
        return;
      }
      await client.deleteUser(token: token, userId: userId);
      print('✅ User deleted: ID=$userId');

    default:
      print('❌ Unknown users subcommand: $subcommand');
  }
}

String? _getArgValue(List<String> args, String flag, String? defaultValue) {
  final index = args.indexOf(flag);
  if (index == -1 || index + 1 >= args.length) {
    return defaultValue;
  }
  return args[index + 1];
}

bool _hasArg(List<String> args, String flag) {
  return args.contains(flag);
}

String _parseArg(String flag, String defaultValue) {
  final args = Platform.environment.entries;
  for (final arg in args) {
    if (arg.key == flag) {
      return arg.value;
    }
  }
  // Try from command line
  final index = Platform.script.toString().indexOf(flag);
  return defaultValue;
}

class _InputController {
  // Placeholder for future enhancements
}
