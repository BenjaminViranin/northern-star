import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/split_view_screen.dart';
import '../providers/database_provider.dart';
import '../dialogs/create_note_dialog.dart';
import '../dialogs/create_group_dialog.dart';

class SidebarNavigation extends ConsumerWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final groups = ref.watch(groupsProvider);
    final notes = ref.watch(notesProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        children: [
          // Header with navigation buttons
          _buildNavigationHeader(context, ref, navigationState),

          // Action buttons
          _buildActionButtons(context, ref, navigationState),

          // Content based on selected section
          Expanded(
            child: _buildSectionContent(context, ref, navigationState, groups, notes),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context, WidgetRef ref, NavigationState navigationState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          _buildNavButton(
            context: context,
            ref: ref,
            icon: Icons.note,
            label: 'Notes',
            section: NavigationSection.notes,
            isSelected: navigationState.selectedSection == NavigationSection.notes,
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            context: context,
            ref: ref,
            icon: Icons.folder,
            label: 'Groups',
            section: NavigationSection.groups,
            isSelected: navigationState.selectedSection == NavigationSection.groups,
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            context: context,
            ref: ref,
            icon: Icons.settings,
            label: 'Settings',
            section: NavigationSection.settings,
            isSelected: navigationState.selectedSection == NavigationSection.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required NavigationSection section,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(navigationStateProvider.notifier).selectSection(section);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, NavigationState navigationState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          if (navigationState.selectedSection == NavigationSection.notes) ...[
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.add,
                label: 'New Note',
                onTap: () => _showCreateNoteDialog(context, ref),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.create_new_folder,
                label: 'New Group',
                onTap: () => _showCreateGroupDialog(context, ref),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.view_column,
                label: 'Split View',
                onTap: () => _openSplitView(context),
              ),
            ),
          ] else if (navigationState.selectedSection == NavigationSection.groups) ...[
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.create_new_folder,
                label: 'New Group',
                onTap: () => _showCreateGroupDialog(context, ref),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Icon(icon, size: 18, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(
    BuildContext context,
    WidgetRef ref,
    NavigationState navigationState,
    AsyncValue groups,
    AsyncValue notes,
  ) {
    switch (navigationState.selectedSection) {
      case NavigationSection.notes:
        return _buildNotesSection(context, ref, navigationState, groups, notes);
      case NavigationSection.groups:
        return _buildGroupsSection(context, ref, groups);
      case NavigationSection.settings:
        return _buildSettingsSection(context, ref);
    }
  }

  Widget _buildNotesSection(
    BuildContext context,
    WidgetRef ref,
    NavigationState navigationState,
    AsyncValue groups,
    AsyncValue notes,
  ) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryTeal),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) {
              ref.read(navigationStateProvider.notifier).setSearchQuery(value);
            },
          ),
        ),

        // Notes list organized by groups
        Expanded(
          child: _buildHierarchicalNotesList(context, ref, navigationState, groups, notes),
        ),
      ],
    );
  }

  Widget _buildHierarchicalNotesList(
    BuildContext context,
    WidgetRef ref,
    NavigationState navigationState,
    AsyncValue groups,
    AsyncValue notes,
  ) {
    return groups.when(
      data: (groupsList) => notes.when(
        data: (notesList) {
          // Filter notes based on search query (case-insensitive, searches title and content)
          final searchQuery = navigationState.searchQuery.toLowerCase().trim();
          final filteredNotes = searchQuery.isEmpty
              ? notesList
              : notesList
                  .where((note) => note.title.toLowerCase().contains(searchQuery) || note.plainText.toLowerCase().contains(searchQuery))
                  .toList();

          // If searching, show flat list of matching notes
          if (searchQuery.isNotEmpty) {
            return _buildSearchResults(context, ref, filteredNotes, groupsList, navigationState);
          }

          // Otherwise show hierarchical view
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: groupsList.length,
            itemBuilder: (context, index) {
              final group = groupsList[index];
              final groupNotes = filteredNotes.where((note) => note.groupId == group.id).toList();
              final isExpanded = ref.read(navigationStateProvider.notifier).isGroupExpanded(group.id);

              // If a group is selected for filtering, only show that group
              if (navigationState.selectedGroupId != null && navigationState.selectedGroupId != group.id) {
                return const SizedBox.shrink();
              }

              return _buildGroupSection(context, ref, group, groupNotes, isExpanded, navigationState);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> filteredNotes,
    List<dynamic> groupsList,
    NavigationState navigationState,
  ) {
    if (filteredNotes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No notes found',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        dynamic group;
        try {
          group = groupsList.firstWhere((g) => g.id == note.groupId);
        } catch (e) {
          group = null;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: navigationState.selectedNoteId == note.id ? AppTheme.primaryTeal.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                ref.read(navigationStateProvider.notifier).selectNote(note.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Group color indicator
                    if (group != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Note icon
                    Icon(
                      Icons.description,
                      size: 14,
                      color: navigationState.selectedNoteId == note.id ? AppTheme.primaryTeal : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    // Note title
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: navigationState.selectedNoteId == note.id ? AppTheme.primaryTeal : AppTheme.textPrimary,
                          fontWeight: navigationState.selectedNoteId == note.id ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Group name
                    if (group != null)
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    WidgetRef ref,
    dynamic group,
    List<dynamic> notes,
    bool isExpanded,
    NavigationState navigationState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Material(
          color: navigationState.selectedGroupId == group.id ? AppTheme.primaryTeal.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              // Only expand/collapse the group, don't filter
              ref.read(navigationStateProvider.notifier).toggleGroupExpanded(group.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Expand/collapse button
                  GestureDetector(
                    onTap: () {
                      ref.read(navigationStateProvider.notifier).toggleGroupExpanded(group.id);
                    },
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(int.parse(group.color.substring(1), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: navigationState.selectedGroupId == group.id ? AppTheme.primaryTeal : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${notes.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Notes in group (shown when expanded)
        if (isExpanded) ...notes.map((note) => _buildNoteItem(context, ref, note, navigationState.selectedNoteId == note.id)),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNoteItem(BuildContext context, WidgetRef ref, dynamic note, bool isSelected) {
    return Material(
      color: isSelected ? AppTheme.primaryTeal.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          ref.read(navigationStateProvider.notifier).selectNote(note.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.description,
                size: 14,
                color: isSelected ? AppTheme.primaryTeal : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppTheme.primaryTeal : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsSection(BuildContext context, WidgetRef ref, AsyncValue groups) {
    return Container();
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    return Container();
  }

  void _showCreateNoteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }

  void _openSplitView(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SplitViewScreen(),
      ),
    );
  }
}
