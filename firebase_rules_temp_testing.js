rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Temporary rules for testing - REPLACE WITH SECURE RULES LATER
    // Allow all reads and writes for debugging
    match /{document=**} {
      allow read, write: if true;
    }
  }
}