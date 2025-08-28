# Lights Attendance Management System

A comprehensive Flutter-based mobile application for employee attendance tracking with Firebase backend integration.

## Features

### 🏢 Company-Based Management

- **One Admin per Company**: Only one admin can register per company
- **Employee Management**: Admins can create and manage employee accounts
- **Role-Based Authentication**: Separate login flows for admins and employees
- **Company Isolation**: Data is isolated per company for security

### 📅 Holiday Management

- **Admin Holiday Declaration**: Admins can declare company holidays
- **Calendar Synchronization**: Holidays automatically appear on all employee calendars
- **Holiday Types**: Support for national, company, and optional holidays
- **Holiday Statistics**: Overview of holiday distribution and upcoming events

### 👥 User Management

- **Firebase Authentication**: Secure login with email/password
- **User Profiles**: Complete user information with roles and permissions
- **Employee Creation**: Admins can create employee accounts with company assignment
- **User Status Management**: Activate/deactivate employee accounts

### 🎨 Professional UI/UX

- **Material Design 3**: Modern and clean interface
- **Professional Theme**: Corporate-grade color scheme and styling
- **Onboarding Flow**: Welcome screen for first-time users
- **Responsive Design**: Optimized for various screen sizes
- **Dark Theme Support**: Light and dark theme options

### 📱 Cross-Platform

- **Flutter Framework**: Single codebase for iOS and Android
- **Native Performance**: Optimized for mobile platforms
- **Offline Capability**: Basic offline functionality with Firebase caching

## Architecture

### MVC Pattern

- **Models**: Data structures for User, Company, Holiday, Attendance
- **Views**: UI screens and widgets
- **Controllers**: Business logic and state management with GetX
- **Services**: Firebase integration and API services

### Technology Stack

- **Framework**: Flutter 3.8+
- **State Management**: GetX
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Local Storage**: SharedPreferences
- **UI Components**: Material Design 3, TableCalendar
- **Image Handling**: Image Picker, Cached Network Image

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── theme/
│   └── app_theme.dart                 # Professional app theme
├── models/
│   ├── user_model.dart                # User data model
│   ├── company_model.dart             # Company data model
│   ├── holiday_model.dart             # Holiday data model
│   └── attendance_model.dart          # Attendance data model
├── services/
│   └── firebase_service.dart          # Firebase CRUD operations
├── controllers/
│   ├── auth_controller.dart           # Authentication logic
│   └── holiday_controller.dart        # Holiday management logic
├── views/
│   ├── auth/
│   │   ├── onboarding_screen.dart     # Welcome/onboarding
│   │   └── login_screen.dart          # Login/register screen
│   ├── admin/
│   │   ├── admin_dashboard_screen.dart       # Admin main dashboard
│   │   ├── holiday_management_screen.dart    # Holiday management
│   │   └── employee_management_screen.dart   # Employee management
│   └── employee/
│       └── employee_dashboard_screen.dart    # Employee dashboard
└── widgets/
    └── shared_calendar_widget.dart    # Reusable calendar component
```

## Setup Instructions

### Prerequisites

- Flutter 3.8+ installed
- Firebase project configured
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd attendence
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Firebase Setup**

   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Create Firestore database
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` with your configuration

4. **Firestore Security Rules**

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Companies collection
       match /companies/{companyId} {
         allow read, write: if request.auth != null;
       }

       // Users collection
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
         allow read: if request.auth != null;
       }

       // Holidays collection
       match /holidays/{holidayId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null &&
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }
     }
   }
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

## Usage

### First Time Setup

1. **Onboarding**: New users see a welcome screen with app introduction
2. **Company Registration**: First admin registers their company
3. **Employee Creation**: Admin creates employee accounts
4. **Login**: Both admin and employees can log in with created credentials

### Admin Workflow

1. **Dashboard**: Overview of company holidays and statistics
2. **Holiday Management**: Declare holidays that sync to all employee calendars
3. **Employee Management**: Create, view, and manage employee accounts
4. **Reports**: View attendance reports and analytics (coming soon)

### Employee Workflow

1. **Dashboard**: View personal attendance and company calendar
2. **Calendar View**: See all company holidays and personal attendance
3. **Attendance Marking**: Clock in/out functionality (coming soon)
4. **Leave Requests**: Submit leave requests for approval (coming soon)

## API Reference

### Firebase Collections

#### Companies

```json
{
  "id": "company_id",
  "name": "Company Name",
  "address": "Company Address",
  "phone": "Contact Number",
  "email": "company@email.com",
  "adminId": "admin_user_id",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### Users

```json
{
  "id": "user_id",
  "name": "User Name",
  "email": "user@email.com",
  "role": "admin|employee",
  "companyId": "company_id",
  "isActive": true,
  "phone": "phone_number",
  "address": "user_address",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### Holidays

```json
{
  "id": "holiday_id",
  "name": "Holiday Name",
  "date": "timestamp",
  "type": "national|company|optional",
  "description": "Holiday Description",
  "companyId": "company_id",
  "createdBy": "admin_user_id",
  "createdAt": "timestamp"
}
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Create a Pull Request

## Development Guidelines

### Code Style

- Follow Dart/Flutter style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent file structure

### State Management

- Use GetX for state management
- Keep controllers focused and lightweight
- Implement proper error handling
- Use reactive programming patterns

### UI/UX Guidelines

- Follow Material Design 3 principles
- Maintain consistent theming
- Implement proper loading states
- Add helpful error messages

## Future Enhancements

### Planned Features

- [ ] **Attendance Tracking**: GPS-based check-in/check-out
- [ ] **Leave Management**: Leave request and approval workflow
- [ ] **Reports & Analytics**: Detailed attendance reports
- [ ] **Notifications**: Push notifications for important events
- [ ] **Biometric Auth**: Fingerprint/face recognition login
- [ ] **Offline Mode**: Full offline functionality
- [ ] **Multi-language**: Localization support
- [ ] **Advanced Security**: Role-based permissions

### Technical Improvements

- [ ] **Performance Optimization**: Lazy loading and caching
- [ ] **Error Handling**: Comprehensive error management
- [ ] **Logging**: Detailed application logging
- [ ] **Monitoring**: Crash reporting and analytics
- [ ] **Testing**: Complete test coverage

---

**Lights Attendance Management System** - Professional attendance tracking made simple.
