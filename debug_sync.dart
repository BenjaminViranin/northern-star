import 'package:flutter/material.dart';
import 'lib/data/database/database.dart';
import 'lib/core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  print('🔍 Debugging sync issues...');
  
  // Initialize database
  final database = AppDatabase();
  
  try {
    // Check authentication status
    print('\n📱 Authentication Status:');
    print('   Is authenticated: ${SupabaseConfig.isAuthenticated}');
    print('   Current user: ${SupabaseConfig.currentUser?.id}');
    
    // Check local database state
    print('\n💾 Local Database State:');
    final localGroups = await database.getAllGroups();
    final localNotes = await database.getAllNotes();
    final syncQueue = await database.getPendingSyncOperations();
    
    print('   Local groups: ${localGroups.length}');
    for (final group in localGroups) {
      print('     - ${group.name} (ID: ${group.id}, Supabase ID: ${group.supabaseId}, Needs Sync: ${group.needsSync})');
    }
    
    print('   Local notes: ${localNotes.length}');
    for (final note in localNotes) {
      print('     - ${note.title} (ID: ${note.id}, Group: ${note.groupId}, Supabase ID: ${note.supabaseId}, Needs Sync: ${note.needsSync})');
    }
    
    print('   Sync queue operations: ${syncQueue.length}');
    for (final op in syncQueue) {
      print('     - ${op.operation} ${op.entityTable} (Local ID: ${op.localId}, Retry: ${op.retryCount})');
    }
    
    // If authenticated, check server state
    if (SupabaseConfig.isAuthenticated) {
      print('\n☁️ Server Database State:');
      try {
        final serverGroups = await SupabaseConfig.client
            .from('groups')
            .select()
            .eq('user_id', SupabaseConfig.currentUser!.id)
            .eq('is_deleted', false);
        
        final serverNotes = await SupabaseConfig.client
            .from('notes')
            .select()
            .eq('user_id', SupabaseConfig.currentUser!.id)
            .eq('is_deleted', false);
        
        print('   Server groups: ${serverGroups.length}');
        for (final group in serverGroups) {
          print('     - ${group['name']} (ID: ${group['id']})');
        }
        
        print('   Server notes: ${serverNotes.length}');
        for (final note in serverNotes) {
          print('     - ${note['title']} (ID: ${note['id']})');
        }
      } catch (e) {
        print('   ❌ Failed to fetch server data: $e');
      }
    }
    
    // Test creating a group locally
    print('\n🧪 Testing local group creation...');
    try {
      final groupId = await database.insertGroup(GroupsCompanion.insert(
        name: 'Debug Test Group',
        color: '#ff0000',
        needsSync: const Value(true),
      ));
      print('   ✅ Created local group with ID: $groupId');
      
      // Add to sync queue manually to test
      await database.addToSyncQueue(SyncQueueCompanion.insert(
        operation: 'create',
        entityTable: 'groups',
        localId: groupId,
        data: '{"name": "Debug Test Group", "color": "#ff0000"}',
      ));
      print('   ✅ Added to sync queue');
      
      // Check sync queue again
      final updatedSyncQueue = await database.getPendingSyncOperations();
      print('   Updated sync queue operations: ${updatedSyncQueue.length}');
      
    } catch (e) {
      print('   ❌ Failed to create test group: $e');
    }
    
  } catch (e) {
    print('❌ Debug failed: $e');
  } finally {
    await database.close();
  }
}
