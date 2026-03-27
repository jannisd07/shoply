#!/bin/bash

# Test Push Notification via Firebase API
# You need to get your Server Key from Firebase Console

SERVER_KEY="YOUR_FIREBASE_SERVER_KEY"
FCM_TOKEN="cdI6YJ8msU7_jvt1qkqIJ6:APA91bGLnDAg2pxorn13FAxUN8laqFMlw_48GOzJVUn9qnFAh0YLB9nXwbQdHqR_FFTZ---tXimA9JQ16YZTGswKJryre6ekuxdP2iWKRb4NjEfQuVOeC64"

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "'$FCM_TOKEN'",
    "notification": {
      "title": "Test from curl",
      "body": "If you see this, push notifications work!"
    },
    "priority": "high"
  }'
