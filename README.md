# 📝 Complaint Management System  
A full-stack **Flutter + Django** application for logging, classifying, and managing complaints.  

The system allows users to submit complaints via a Flutter mobile app. The backend, built with Django, processes and classifies complaints (subcategory, severity, priority) and updates a live dashboard.  

---

## 📌 Features  

### Frontend (Flutter)  
- Complaint submission form with text input.  
- Sends complaint data via **HTTP POST** to the Django backend.  
- Handles responses with user-friendly JSON formatting (subcategory, severity, priority).  
- Android 9+ support with `network_security_config.xml` and `usesCleartextTraffic`.  
- `OnBackInvokedCallback` enabled for smoother navigation.
- Works for Android, iOS, Windows and MacOS. 

### Backend (Django)  
- REST API for receiving and processing complaint submissions.  
- Classification of complaints into subcategories with severity & priority levels.  
- Auto-updating dashboard whenever new complaints are logged.  
- `populate_db` and `populate_dashboard.py` scripts for seeding/updating the database.  
- Custom endpoint to allow **partial updates** (only modifies parameters present in the request).  

---
## 🔧 Setup  

### Backend (Django)  
1. Navigate to the backend folder:  
```
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```
##  Frontend
```
cd frontend
flutter pub get
flutter run

```
## 🚀 Tech Stack

Frontend: Flutter (Dart)

Backend: Django (Python)

Database: SQLite / PostgreSQL (configurable)

APIs: REST
--
<img width="2558" height="1263" alt="image" src="https://github.com/user-attachments/assets/c8f3f6b9-4ae8-4dbd-a3fd-53c1f6a8a06a" />
<img width="2556" height="1260" alt="image" src="https://github.com/user-attachments/assets/2107493c-a0a3-4033-ac97-3fa2159ca7d1" />
<img width="2559" height="906" alt="image" src="https://github.com/user-attachments/assets/cd08918d-5274-4698-ae58-06b084b9dc2c" />
<img width="2553" height="1270" alt="Screenshot 2025-09-18 120300" src="https://github.com/user-attachments/assets/fd179d27-6b8c-4f34-89fd-5ce6d815b631" />
<img width="2559" height="1256" alt="Screenshot 2025-09-18 120311" src="https://github.com/user-attachments/assets/c70b5161-2b37-483b-a318-8dbac203a2b5" />
