import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/profile/models/interview_folder.dart';
import 'package:ai/features/profile/interview_folder_page.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class InterviewHistoryPage extends StatefulWidget {
  const InterviewHistoryPage({super.key});
  @override
  State<InterviewHistoryPage> createState() => _InterviewHistoryPageState();
}

class _InterviewHistoryPageState extends State<InterviewHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final foldersStream = userDoc
        .collection('interviewFolders')
        .orderBy('updatedAt', descending: true)
        .snapshots();
    final recordsStream = userDoc
        .collection('interviews')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('면접 영상 & 결과'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: foldersStream,
        builder: (context, foldersSnapshot) {
          if (foldersSnapshot.hasError) {
            return const Center(
              child: Text('폴더 정보를 불러오지 못했습니다.'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: recordsStream,
            builder: (context, recordsSnapshot) {
              if (recordsSnapshot.hasError) {
                return const Center(
                  child: Text('면접 기록을 불러오지 못했습니다.'),
                );
              }

              if ((foldersSnapshot.connectionState == ConnectionState.waiting &&
                      !foldersSnapshot.hasData) ||
                  (recordsSnapshot.connectionState == ConnectionState.waiting &&
                      !recordsSnapshot.hasData)) {
                return const Center(child: CircularProgressIndicator());
              }

              final folderDocs = foldersSnapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final recordDocs = recordsSnapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              final folders = folderDocs.map(InterviewFolder.fromDoc).toList();
              final records = recordDocs.map(InterviewRecord.fromDoc).toList();

              if (folders.isEmpty && records.isEmpty) {
                return const _EmptyHistoryState();
              }

              final folderIdSet = folderDocs.map((doc) => doc.id).toSet();
              final folderById = {
                for (final folder in folders) folder.id: folder
              };
              final groupedRecords = <String, List<InterviewRecord>>{};
              for (final record in records) {
                groupedRecords
                    .putIfAbsent(record.folderId, () => [])
                    .add(record);
              }

              for (final entry in groupedRecords.entries) {
                folderById.putIfAbsent(
                  entry.key,
                  () => InterviewFolder(
                    id: entry.key,
                    category: entry.value.first.category,
                    defaultName: entry.value.first.category.title,
                    createdAt: entry.value.first.createdAt,
                    updatedAt: entry.value.first.createdAt,
                  ),
                );
              }

              final foldersToShow = folderById.values.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: foldersToShow.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final folder = foldersToShow[index];
                  final folderRecords =
                      groupedRecords[folder.id] ?? const <InterviewRecord>[];
                  final canRename = folderIdSet.contains(folder.id);
                  return _FolderTile(
                    folder: folder,
                    records: folderRecords,
                    canRename: canRename,
                    onRename: canRename
                        ? () => _handleRenameFolder(
                              userDoc
                                  .collection('interviewFolders')
                                  .doc(folder.id),
                              folder,
                            )
                        : null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleRenameFolder(
    DocumentReference<Map<String, dynamic>> folderRef,
    InterviewFolder folder,
  ) async {
    if (!mounted) return;

    final controller =
        TextEditingController(text: folder.customName ?? folder.defaultName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('폴더 이름 수정'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '폴더 이름을 입력하세요.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || newName == null) {
      return;
    }

    try {
      await folderRef.update({
        'customName': newName.isEmpty ? null : newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('폴더 이름을 저장하지 못했습니다. 다시 시도해 주세요.')),
        );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.records,
    required this.canRename,
    this.onRename,
  });

  final InterviewFolder folder;
  final List<InterviewRecord> records;
  final bool canRename;
  final VoidCallback? onRename;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/profile/history/folder',
          extra: InterviewFolderPageArgs(folder: folder),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 32, color: AppColors.mint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${records.length}개의 면접 영상',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtext,
                    ),
                  ),
                ],
              ),
            ),
            if (canRename)
              IconButton(
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '폴더 이름 변경',
              ),
            const Icon(Icons.chevron_right, color: AppColors.subtext),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.play_circle_outline,
            size: 48,
            color: AppColors.subtext,
          ),
          SizedBox(height: 16),
          Text(
            '아직 저장된 면접 기록이 없습니다.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}
