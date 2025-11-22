// FCM으로 관리자·기업 사용자에게 알림을 보내는 Firebase Functions 진입점.
import * as functions from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

async function createNotification(userId, payload) {
  if (!userId) {
    return null;
  }
  return db
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
        ...payload,
      });
}

function collectTokensFromUser(doc) {
  const data = doc.data() || {};
  const tokens = data.fcmTokens;
  if (!Array.isArray(tokens)) {
    return [];
  }
  return tokens.filter((token) => typeof token === 'string');
}

async function fetchAdminTokens() {
  const admins = await db.collection('users').where('role', '==', 'admin').get();
  return admins.docs
      .map((doc) => collectTokensFromUser(doc))
      .reduce((acc, cur) => acc.concat(cur), []);
}

export const notifyCorporateApproval = functions.firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const uid = context.params.uid;
    const role = after.role;

    const statusChanged = before.isApproved !== after.isApproved;
    const isCorporate = role === 'corporate' || role === 'company';

    if (!statusChanged || !isCorporate) {
      return null;
    }

    const approved = after.isApproved === true;
    const tokens = new Set();

    collectTokensFromUser(change.after).forEach((token) => tokens.add(token));
    (await fetchAdminTokens()).forEach((token) => tokens.add(token));

    if (tokens.size === 0) {
      return null;
    }

    const notification = {
      title: approved ? '기업 회원 승인 완료' : '기업 회원 승인 거절',
      body: approved
        ? '관리자가 계정을 승인했습니다. 이제 서비스를 이용할 수 있습니다.'
        : '승인이 거절되었습니다. 입력 정보를 확인해주세요.',
    };

    await messaging.sendEachForMulticast({
      tokens: Array.from(tokens),
      notification,
      data: {
        uid,
        approvalStatus: approved ? 'approved' : 'rejected',
      },
    });

    return null;
  });
  export const notifyOnAdminPostHide = functions.firestore
    .document('communityPosts/{postId}')
    .onUpdate(async (change) => {
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      const turnedHidden = before.visible !== false && after.visible === false;
      if (!turnedHidden || after.deletedByAdmin !== true) {
        return null;
      }

      const authorId = after.authorId;
      const title = '게시글이 삭제되었습니다';
      const message = after.blockedReason
        || '관리자가 정책 위반으로 게시글을 삭제했습니다.';

      await createNotification(authorId, {
        type: 'delete',
        title,
        message,
      });

      return null;
    });

export const notifyOnPostLike = functions.firestore
    .document('communityPosts/{postId}/likes/{userId}')
    .onCreate(async (_, context) => {
      const { postId, userId } = context.params;
      const post = await db.collection('communityPosts').doc(postId).get();
      const data = post.data() || {};
      const authorId = data.authorId;

      if (!authorId || authorId === userId) {
        return null;
      }

      await createNotification(authorId, {
        type: 'like',
        title: '게시글에 좋아요가 달렸습니다',
        message: `${data.title || '게시글'}에 새 좋아요가 있습니다.`,
      });

      return null;
    });

export const notifyOnCommentLike = functions.firestore
    .document('communityPosts/{postId}/comments/{commentId}/likes/{userId}')
    .onCreate(async (_, context) => {
      const { postId, commentId, userId } = context.params;
      const comment = await db
          .collection('communityPosts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();
      const data = comment.data() || {};
      const authorId = data.authorId;

      if (!authorId || authorId === userId) {
        return null;
      }

      await createNotification(authorId, {
        type: 'like',
        title: '댓글에 좋아요가 달렸습니다',
        message: data.content
          ? `"${data.content}" 댓글에 좋아요가 추가되었습니다.`
          : '작성한 댓글에 좋아요가 달렸습니다.',
      });

      return null;
    });

export const notifyAdminsOnCorporateSignup = functions.firestore
  .document('corporate_signups/{docId}')
  .onCreate(async (snapshot) => {
    const tokens = await fetchAdminTokens();
    if (!tokens.length) {
      return null;
    }

    const data = snapshot.data() || {};
    const company = data.companyName || data.name || '기업 회원';

    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: '새 기업 회원 승인 요청',
        body: `${company}의 가입 신청이 접수되었습니다.`,
      },
      data: {
        applicant: company,
        type: 'corporate_signup',
      },
    });

    return null;
  });