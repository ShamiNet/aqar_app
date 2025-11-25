import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * الدالة الحالية: تحديث سمعة المستخدم عند إضافة تقييم جديد.
 */
export const updateReputation = onDocumentCreated(
  "users/{userId}/ratings/{ratingId}",
  async (event) => {
    const userId = event.params.userId;
    const userRef = db.collection("users").doc(userId);
    logger.log(
      `New rating for user: ${userId}. Starting reputation update.`,
    );

    return db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        logger.error(`User document ${userId} not found.`);
        return;
      }

      const userData = userDoc.data() || {};
      const currentScore = userData.reputationScore || 0.0;
      const currentCount = userData.reputationCount || 0;

      const newRatingData = event.data?.data();
      const newRating = newRatingData?.rating || 0;

      if (newRating <= 0 || newRating > 5) {
        logger.warn(
          `Invalid rating value (${newRating}) for user ${userId}. Ignoring.`,
        );
        return;
      }

      const newTotalScore = currentScore * currentCount + newRating;
      const newCount = currentCount + 1;
      const newAverageScore = newTotalScore / newCount;

      logger.log(
        `Updating user ${userId}: New Count=${newCount}, ` +
        `New Score=${newAverageScore.toFixed(2)}`,
      );

      transaction.update(userRef, {
        reputationScore: newAverageScore,
        reputationCount: newCount,
      });
    });
  },
);

