# Brain Tumor Detection Mobile Application

## Overview

This Flutter application allows users to upload MRI brain images and receive predictions from a Flask-based backend API. The app provides visualization, risk assessment, and report generation.

## Features

* User registration and login
* Image upload for prediction
* Tumor classification results
* Confidence score and risk level display
* Heatmap visualization
* Prediction history tracking
* PDF report generation
* Dark theme support

## Technology Stack

* Flutter (Dart)
* REST API integration
* SharedPreferences for session handling

## Backend Integration

This application communicates with a Flask API hosted on Render.

Base URL:
https://brain-tumor-api-zg3b.onrender.com

## Application Screens

* Login Screen
* Registration Screen
* Dashboard
* Upload Screen
* Result Screen
* History Screen
* Profile Screen

## Setup Instructions

1. Install dependencies:
   flutter pub get

2. Run the application:
   flutter run

## Build APK

Debug:
flutter build apk

Release:
flutter build apk --release

## Notes

* Ensure correct API base URL is configured.
* Internet permission must be enabled in AndroidManifest.xml.
* Error handling is implemented for API failures.

## Author

C5 Team
