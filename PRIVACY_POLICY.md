# Privacy Policy (InstaMarQ – Face Recognition Attendance System)
**Effective date:** 2026-01-27

This Privacy Policy explains how **InstaMarQ** (the “App”) collects, uses, and shares information when you use the App.

The App is intended for organizations to manage employee attendance using face image capture and related HR features (attendance, employee profiles, leave requests).

## Who controls the data
- **Organization / Employer (Customer)**: In most deployments, your employer/organization controls the employee data processed through the App and determines retention and access.
- **App Operator / Developer**: The party operating the backend services the App connects to (see “Backend services and endpoints” below).

If you are an employee using the App, your requests about your personal data may need to be handled by your employer/organization.

## Information we collect
### 1) Account and identity information
- **Login details**: mobile number and password used to sign in.
- **Authentication token**: stored on your device to keep you signed in.

### 2) Employee profile and HR data
Depending on your role and what your organization enables, the App may collect and/or display:
- **Employee profile data**: name, phone number, email (optional), department, shift, date of joining, date of birth, salary (if used in your deployment).
- **Attendance records**: check-in/check-out timestamps and related status/metadata returned by the backend.
- **Leave requests**: leave type, dates, reason, and related approval status.

### 3) Face images (camera/gallery)
The App can capture or select images to support face-based attendance and employee registration, including:
- **Employee registration image** (face image) submitted during employee creation/registration.
- **Attendance capture image** submitted when marking attendance.

These images may be uploaded to backend services for face recognition and attendance processing. The backend may store the uploaded images and/or derived face features/templates as required to provide the service and prevent fraud (exact storage behavior depends on your server configuration and organization policy).

### 4) Location data (precise)
When you mark attendance, the App may collect your **approximate or precise location** (latitude/longitude) and send it with the attendance request if available. Location is used to:
- help verify attendance events (for example, on-site vs off-site),
- support organization compliance requirements.

### 5) Files you choose to upload (e.g., leave certificate)
If you attach a certificate while applying for leave, the App uploads the selected file/image to the backend along with your leave request.

### 6) Device and usage information
The App and backend services may collect basic technical data such as:
- device identifiers and OS version,
- network information (e.g., IP address),
- app logs and error details necessary for troubleshooting and security.

## How we use information
We use the information described above to:
- **Provide core functionality**: sign-in, employee management, face-based attendance, attendance reports, leave workflows.
- **Verify identity and prevent misuse**: detect fraudulent attendance attempts and protect accounts.
- **Improve reliability and support**: debug issues, monitor performance, and respond to support requests.
- **Meet legal/organizational requirements**: maintain records required by your organization or applicable law.

## Permissions (why the App asks)
The App may request:
- **Camera**: to capture face images for registration and attendance.
- **Photos/Media (storage)**: to select images from gallery (e.g., certificate upload) and to handle captured images.
- **Location**: to attach location coordinates to attendance events (when enabled/available).
- **Network/Internet**: to communicate with backend APIs.

You can control these permissions in your device settings. If you deny certain permissions, parts of the App may not work (for example, face attendance without camera, or attendance with location when location permission is denied).

## Backend services and endpoints
The App communicates with backend services to perform authentication, employee management, and attendance actions. In the current codebase, the App is configured to call:
- `https://face.agniplay.com/api` (attendance/face-related endpoints, including image upload for attendance and registration)
- `https://nodeface.agniplay.com/api` (user management, reports, leave APIs)

Some builds may also use a **local** face-recognition service endpoint for development/testing:
- `http://localhost:5000` (local development face-recognition service)

Your organization/operator may change these endpoints for production.

## How we share information
We may share information:
- **With your organization/employer**: admins and authorized staff may access attendance, employee profiles, and leave details as part of workforce management.
- **With service providers**: hosting, infrastructure, and support providers who process data on behalf of the operator (subject to contractual and security obligations).
- **For legal reasons**: if required to comply with law, enforce policies, or protect rights and safety.

We do **not** sell your personal information.

## Data retention
Retention is determined by the backend operator and/or your organization. Common retention includes:
- **Attendance and HR records** retained for as long as required for operational and legal purposes.
- **Face images/templates** retained as needed to provide face recognition and fraud prevention, and per organization policy.

To request deletion or export, contact your organization’s administrator or the contact listed below.

## Security
We use reasonable administrative, technical, and organizational measures to protect data. Data transmitted to remote services should be protected using encryption in transit (for example, HTTPS). No method of transmission or storage is 100% secure.

## Children’s privacy
The App is intended for workplace use and is **not directed to children**. Do not use the App if you are under the age required to consent to data processing in your jurisdiction.

## Your choices and rights
Depending on your location and your organization’s role as data controller, you may have rights to:
- access, correct, or delete your personal data,
- object to or restrict certain processing,
- withdraw consent (where applicable),
- request a copy/export of your data.

To exercise these rights, contact your organization’s administrator or reach out using the contact below.

## Changes to this policy
We may update this Privacy Policy from time to time. If changes are material, we will provide notice in the App or through your organization’s normal communication channels. The “Effective date” above indicates when this version is effective.

## Contact
For privacy questions or requests, contact:
- **Organization admin**: your employer/organization’s HR or system administrator
- **App/operator contact**: *(replace with your official contact)* `privacy@yourcompany.com`

