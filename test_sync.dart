import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Test script to validate sync functionality
void main() async {
  print('🧪 Starting sync functionality tests...');
  
  // Test configuration
  const supabaseUrl = 'https://xfsdvhqryzrieqmdecps.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhmc2R2aHFyeXpyaWVxbWRlY3BzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4NjQ1MTEsImV4cCI6MjA3MjQ0MDUxMX0.adlSvEfshkLIXkzagnOfWe2tWNqRPwytCA0rzVXvqEo';
  
  // Test user credentials (you'll need to authenticate first)
  const testEmail = 'test@example.com';
  const testPassword = 'testpassword123';
  
  try {
    // Step 1: Authenticate with Supabase
    print('🔐 Authenticating with Supabase...');
    final authResponse = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseAnonKey,
      },
      body: jsonEncode({
        'email': testEmail,
        'password': testPassword,
      }),
    );
    
    if (authResponse.statusCode != 200) {
      print('❌ Authentication failed: ${authResponse.body}');
      return;
    }
    
    final authData = jsonDecode(authResponse.body);
    final accessToken = authData['access_token'];
    final userId = authData['user']['id'];
    
    print('✅ Authenticated successfully. User ID: $userId');
    
    // Step 2: Check initial state
    print('\n📊 Checking initial state...');
    await checkDatabaseState(supabaseUrl, supabaseAnonKey, accessToken);
    
    // Step 3: Create test data on server to test pull sync
    print('\n📝 Creating test data on server...');
    await createTestDataOnServer(supabaseUrl, supabaseAnonKey, accessToken, userId);
    
    // Step 4: Wait for app to sync (or trigger manual sync)
    print('\n⏳ Waiting for sync to complete...');
    print('   Please trigger a manual sync in the app now...');
    print('   Press Enter when sync is complete...');
    stdin.readLineSync();
    
    // Step 5: Verify final state
    print('\n🔍 Verifying final state...');
    await checkDatabaseState(supabaseUrl, supabaseAnonKey, accessToken);
    
    print('\n✅ Sync test completed successfully!');
    
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}

Future<void> checkDatabaseState(String baseUrl, String apiKey, String token) async {
  // Check groups
  final groupsResponse = await http.get(
    Uri.parse('$baseUrl/rest/v1/groups?select=*'),
    headers: {
      'apikey': apiKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  if (groupsResponse.statusCode == 200) {
    final groups = jsonDecode(groupsResponse.body) as List;
    print('   Groups in database: ${groups.length}');
    for (final group in groups) {
      print('     - ${group['name']} (${group['color']})');
    }
  }
  
  // Check notes
  final notesResponse = await http.get(
    Uri.parse('$baseUrl/rest/v1/notes?select=*'),
    headers: {
      'apikey': apiKey,
      'Authorization': 'Bearer $token',
    },
  );
  
  if (notesResponse.statusCode == 200) {
    final notes = jsonDecode(notesResponse.body) as List;
    print('   Notes in database: ${notes.length}');
    for (final note in notes) {
      print('     - ${note['title']}');
    }
  }
}

Future<void> createTestDataOnServer(String baseUrl, String apiKey, String token, String userId) async {
  // Create a test group
  final groupResponse = await http.post(
    Uri.parse('$baseUrl/rest/v1/groups'),
    headers: {
      'Content-Type': 'application/json',
      'apikey': apiKey,
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': 'Test Group from Server',
      'color': '#9333ea',
      'user_id': userId,
    }),
  );
  
  if (groupResponse.statusCode == 201) {
    final groupData = jsonDecode(groupResponse.body);
    final groupId = groupData[0]['id'];
    print('✅ Created test group: $groupId');
    
    // Create a test note
    final noteResponse = await http.post(
      Uri.parse('$baseUrl/rest/v1/notes'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': 'Test Note from Server',
        'content': '{"ops":[{"insert":"This is a test note created on the server\\n"}]}',
        'markdown': 'This is a test note created on the server',
        'plain_text': 'This is a test note created on the server',
        'group_id': groupId,
        'user_id': userId,
      }),
    );
    
    if (noteResponse.statusCode == 201) {
      print('✅ Created test note');
    } else {
      print('❌ Failed to create test note: ${noteResponse.body}');
    }
  } else {
    print('❌ Failed to create test group: ${groupResponse.body}');
  }
}
