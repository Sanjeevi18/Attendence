# Firestore Indexes Setup

The app requires these composite indexes in Firestore. Please create them in the Firebase Console:

## 1. Attendance Collection Index (User Queries)

Collection: `attendance`
Fields:

- `userId` (Ascending)
- `date` (Ascending)
- `__name__` (Ascending)

## 2. Company-wide Attendance Index

Collection: `attendance`
Fields:

- `companyId` (Ascending)
- `date` (Ascending)
- `__name__` (Ascending)

## 3. Leave Requests Index (User Queries)

Collection: `leave_requests`
Fields:

- `userId` (Ascending)
- `createdAt` (Descending)
- `__name__` (Ascending)

## 4. Leave Requests Index (Admin Pending)

Collection: `leave_requests`
Fields:

- `companyId` (Ascending)
- `status` (Ascending)
- `createdAt` (Ascending)
- `__name__` (Ascending)

## 5. Leave Requests Index (Admin All)

Collection: `leave_requests`
Fields:

- `companyId` (Ascending)
- `createdAt` (Descending)
- `__name__` (Ascending)

## How to create indexes:

### Method 1: Direct Links (Recommended)

Click these links to automatically create indexes:

1. **Attendance (User)**: Use the Firebase Console link from error messages
2. **Leave Requests (Company+Status)**: Use the Firebase Console link from error messages

### Method 2: Manual Creation

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project: `ligths-ac17d`
3. Go to Firestore Database
4. Click on "Indexes" tab
5. Click "Create Index"
6. For each index above:
   - Collection ID: respective collection name
   - Add fields in the exact order listed
   - Query Scope: Collection
   - Click "Create"

### Method 3: Firebase CLI

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Deploy indexes: `firebase deploy --only firestore:indexes`

## Current Error Messages and Solutions:

The current error in logs shows:

```
Listen for Query(target=Query(attendance where userId==XXX and date>=2025-09-01 and date<2025-10-01 order by date, __name__)
```

This requires Index #1 above.

## Note:

- Creating indexes may take 5-15 minutes
- The app will show errors until indexes are ready
- You only need to create indexes once per Firebase project
- Monitor the Firebase Console for index build progress
