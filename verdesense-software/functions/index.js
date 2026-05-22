const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // 1. Verify the caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to delete users."
    );
  }

  const requesterUid = context.auth.uid;
  const targetUid = data.targetUid;

  if (!targetUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Target UID is required."
    );
  }

  // 2. Fetch the requester's data from the Realtime Database to verify Admin role
  try {
    const requesterSnapshot = await admin
      .database()
      .ref(`users/${requesterUid}`)
      .once("value");
    
    const requesterData = requesterSnapshot.val();

    if (!requesterData || requesterData.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only native administrators can perform system deletions."
      );
    }
  } catch (err) {
    throw new functions.https.HttpsError(
      "internal",
      "Failed to verify administrator privileges."
    );
  }

  // 3. Perform the secure wipe from Authentication and Database
  try {
    // Destroy the Authentication account completely so the email is wiped
    await admin.auth().deleteUser(targetUid);

    // Destroy the Realtime Database profile telemetry and settings deeply
    await admin.database().ref(`users/${targetUid}`).remove();

    return { 
      success: true, 
      message: `User ${targetUid} successfully wiped from Authentication and Database.` 
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      "internal",
      `Failed to destruct user infrastructure: ${error.message}`
    );
  }
});
