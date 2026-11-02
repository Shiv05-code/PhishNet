import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../screens/app_colors.dart';
import 'figma_gradient_background.dart';

class RecentChatsDrawer extends StatelessWidget {
  const RecentChatsDrawer({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.onNewChat,
    required this.onOpenChat,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: FigmaGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Chats',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close recent chats',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.edit_square),
                  title: const Text('New Chat'),
                  onTap: onNewChat,
                ),
                const Divider(),

                Expanded(
                  child: conversations.isEmpty
                      ? const Center(
                          child: Text(
                            'No recent chats yet.\nStart a conversation!',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            final isActive =
                                conversation.id == activeConversationId;

                            return ListTile(
                              leading: Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.primaryBlue,
                              ),
                              title: Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: isActive,
                              selectedTileColor: AppColors.primaryBlue
                                  .withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onTap: () => onOpenChat(conversation.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
