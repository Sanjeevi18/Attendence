# Firestore Indexes Setup

The app requires these composite indexes in Firestore. Please create them in the Firebase Console:

## 1. Attendance Collection Index

Collection: `attendance`
Fields:

- `companyId` (Ascending)
- `userId` (Ascending)
- `date` (Ascending)
- `__name__` (Ascending)

## 2. Company-wide Attendance Index

Collection: `attendance`
Fields:

- `companyId` (Ascending)
- `date` (Ascending)
- `__name__` (Ascending)

## How to create indexes:

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project: `ligths-ac17d`
3. Go to Firestore Database
4. Click on "Indexes" tab
5. Click "Create Index"
6. For each index above:
   - Collection ID: `attendance`
   - Add fields in the exact order listed
   - Query Scope: Collection
   - Click "Create"

Or use the direct links from the error messages to auto-create:

Index 1: https://console.firebase.google.com/v1/r/project/ligths-ac17d/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9saWd0aHMtYWMxN2QvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2F0dGVuZGFuY2UvaW5kZXhlcy9fEAEaDQoJY29tcGFueUlkEAEaCgoGdXNlcklkEAEaCAoEZGF0ZRABGgwKCF9fbmFtZV9fEAE

Index 2: https://console.firebase.google.com/v1/r/project/ligths-ac17d/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9saWd0aHMtYWMxN2QvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2F0dGVuZGFuY2UvaW5kZXhlcy9fEAEaDQoJY29tcGFueUlkEAEaCAoEZGF0ZRABGgwKCF9fbmFtZV9fEAE

## Note:

Creating indexes may take a few minutes. The app will work properly once indexes are ready.
