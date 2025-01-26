// Switch to application database
db = db.getSiblingDB('gaabi_db');

// Create collections
db.createCollection('users');
db.createCollection('tasks');
db.createCollection('habits');
db.createCollection('voice_notes');

// Create indexes
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "createdAt": 1 });

db.tasks.createIndex({ "userId": 1 });
db.tasks.createIndex({ "userId": 1, "dueDate": 1 });
db.tasks.createIndex({ "userId": 1, "status": 1 });

db.habits.createIndex({ "userId": 1 });
db.habits.createIndex({ "userId": 1, "frequency": 1 });
db.habits.createIndex({ "userId": 1, "lastCompletedDate": 1 });

db.voice_notes.createIndex({ "userId": 1 });
db.voice_notes.createIndex({ "userId": 1, "category": 1 });
db.voice_notes.createIndex({ "userId": 1, "createdAt": 1 }); 