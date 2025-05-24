// Global Variables
let currentUser = null;
let userRole = null;

// Demo Users
const users = {
    admin: [
        { id: 'admin001', password: 'admin123', name: 'Dr. Admin' },
        { id: 'admin002', password: 'admin456', name: 'Prof. Administrator' }
    ],
    teacher: [
        { id: 'T001', password: 'teacher123', name: 'Dr. Smith' },
        { id: 'T002', password: 'teacher456', name: 'Prof. Johnson' },
        { id: 'T003', password: 'teacher789', name: 'Dr. Wilson' }
    ]
};

// Global Data Storage
let students = [
    {
        id: 1,
        usn: "1MS21CS001",
        name: "John Doe",
        email: "john@student.edu",
        phone: "9876543210",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 2,
        usn: "1MS21CS002",
        name: "Jane Smith",
        email: "jane@student.edu",
        phone: "9876543211",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 3,
        usn: "1MS21CS003",
        name: "Mike Johnson",
        email: "mike@student.edu",
        phone: "9876543212",
        department: "Computer Science",
        semester: 3,
        section: "B"
    }
];
function handleCSVUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function (e) {
        const lines = e.target.result.split('\n').filter(line => line.trim() !== '');
        const headers = lines[0].split(',').map(h => h.trim().toLowerCase());

        for (let i = 1; i < lines.length; i++) {
            const data = lines[i].split(',').map(value => value.trim());
            if (data.length !== headers.length) continue;

            const newStudent = {
                id: students.length + 1,
                usn: data[headers.indexOf('usn')],
                name: data[headers.indexOf('name')],
                email: data[headers.indexOf('email')],
                phone: data[headers.indexOf('phone')],
                department: data[headers.indexOf('department')],
                semester: parseInt(data[headers.indexOf('semester')]),
                section: data[headers.indexOf('section')]
            };

            students.push(newStudent);
        }

        loadStudents();
        alert('Students uploaded successfully!');
    };

    reader.readAsText(file);
}


let blocks = [
    { id: 1, name: "A Block", floors: 4, description: "Main academic block" },
    { id: 2, name: "B Block", floors: 3, description: "Laboratory block" },
    { id: 3, name: "C Block", floors: 2, description: "Administrative block" }
];

let rooms = [
    { id: 1, roomNumber: "A101", block: "A Block", floor: 1, type: "classroom", capacity: 60, hasProjector: true, hasAC: true },
    { id: 2, roomNumber: "A102", block: "A Block", floor: 1, type: "classroom", capacity: 60, hasProjector: true, hasAC: false },
    { id: 3, roomNumber: "A201", block: "A Block", floor: 2, type: "classroom", capacity: 80, hasProjector: true, hasAC: true },
    { id: 4, roomNumber: "B101", block: "B Block", floor: 1, type: "lab", capacity: 30, hasProjector: true, hasAC: true },
    { id: 5, roomNumber: "B102", block: "B Block", floor: 1, type: "lab", capacity: 30, hasProjector: true, hasAC: false },
    { id: 6, roomNumber: "C101", block: "C Block", floor: 1, type: "seminar_hall", capacity: 100, hasProjector: true, hasAC: true }
];

let timetable = [
    {
        id: 1,
        day: "Monday",
        startTime: "09:00",
        endTime: "10:00",
        subject: "Database Management Systems",
        teacher: "Dr. Smith",
        room: "A201",
        block: "A Block",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 2,
        day: "Monday",
        startTime: "10:00",
        endTime: "11:00",
        subject: "Software Engineering",
        teacher: "Prof. Johnson",
        room: "A102",
        block: "A Block",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 3,
        day: "Monday",
        startTime: "11:00",
        endTime: "12:00",
        subject: "Computer Networks",
        teacher: "Dr. Wilson",
        room: "B101",
        block: "B Block",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 4,
        day: "Tuesday",
        startTime: "09:00",
        endTime: "10:00",
        subject: "Operating Systems",
        teacher: "Prof. Davis",
        room: "A201",
        block: "A Block",
        department: "Computer Science",
        semester: 5,
        section: "A"
    },
    {
        id: 5,
        day: "Tuesday",
        startTime: "10:00",
        endTime: "11:00",
        subject: "Database Lab",
        teacher: "Dr. Smith",
        room: "B102",
        block: "B Block",
        department: "Computer Science",
        semester: 5,
        section: "A"
    }
];

let reservations = [
    {
        id: 1,
        roomNumber: "A101",
        block: "A Block",
        teacherName: "Dr. Smith",
        teacherId: "T001",
        date: "2024-01-15",
        startTime: "14:00",
        endTime: "16:00",
        purpose: "Extra tutorial session for Database Management",
        status: "confirmed"
    },
    {
        id: 2,
        roomNumber: "B101",
        block: "B Block",
        teacherName: "Prof. Johnson",
        teacherId: "T002",
        date: "2024-01-16",
        startTime: "10:00",
        endTime: "12:00",
        purpose: "Programming contest preparation",
        status: "confirmed"
    }
];

// Authentication Functions
function showLoginForm(role) {
    document.querySelector('.role-selection').style.display = 'none';
    document.getElementById('loginForm').style.display = 'block';
    
    const title = document.getElementById('loginTitle');
    const demoCredentials = document.getElementById('demoCredentials');
    
    if (role === 'admin') {
        title.textContent = 'Admin Login';
        demoCredentials.innerHTML = 'ID: admin001 | Password: admin123<br>ID: admin002 | Password: admin456';
    } else if (role === 'teacher') {
        title.textContent = 'Teacher Login';
        demoCredentials.innerHTML = 'ID: T001 | Password: teacher123<br>ID: T002 | Password: teacher456<br>ID: T003 | Password: teacher789';
    }
    
    // Store the selected role
    window.selectedRole = role;
}

function hideLoginForm() {
    document.querySelector('.role-selection').style.display = 'flex';
    document.getElementById('loginForm').style.display = 'none';
    document.getElementById('loginForm').querySelector('form').reset();
}

function handleLogin(event) {
    event.preventDefault();
    
    const loginId = document.getElementById('loginId').value;
    const password = document.getElementById('loginPassword').value;
    const role = window.selectedRole;
    
    // Validate credentials
    const user = users[role].find(u => u.id === loginId && u.password === password);
    
    if (user) {
        currentUser = user;
        userRole = role;
        
        // Hide login screen and show main app
        document.getElementById('loginScreen').style.display = 'none';
        document.getElementById('mainApp').style.display = 'block';
        
        // Update UI based on role
        updateUIForRole();
        
        // Load initial data
        initializeApp();
        
        // Show success message
        setTimeout(() => {
            alert(`Welcome, ${user.name}!`);
        }, 500);
    } else {
        alert('Invalid credentials. Please try again.');
    }
}

function loginAsGuest() {
    currentUser = { name: 'Guest', id: 'guest' };
    userRole = 'guest';
    
    // Hide login screen and show main app
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('mainApp').style.display = 'block';
    
    // Update UI based on role
    updateUIForRole();
    
    // Load initial data
    initializeApp();
}

function logout() {
    if (confirm('Are you sure you want to logout?')) {
        currentUser = null;
        userRole = null;
        
        // Show login screen and hide main app
        document.getElementById('loginScreen').style.display = 'flex';
        document.getElementById('mainApp').style.display = 'none';
        
        // Reset login form
        hideLoginForm();
        
        // Reset to dashboard
        showSection('dashboard');
    }
}

function updateUIForRole() {
    const userWelcome = document.getElementById('userWelcome');
    userWelcome.textContent = `Welcome, ${currentUser.name} (${userRole.charAt(0).toUpperCase() + userRole.slice(1)})`;
    
    // Update navigation based on role
    const roomsNavBtn = document.getElementById('roomsNavBtn');
    const reservationsNavBtn = document.getElementById('reservationsNavBtn');
    const roomsDashCard = document.getElementById('roomsDashCard');
    const reservationsDashCard = document.getElementById('reservationsDashCard');
    
    if (userRole === 'guest') {
        // Disable rooms management for guests
        roomsNavBtn.classList.add('disabled');
        roomsNavBtn.onclick = () => alert('Access restricted. Only administrators can manage rooms.');
        roomsDashCard.classList.add('disabled');
        roomsDashCard.onclick = () => alert('Access restricted. Only administrators can manage rooms.');
        
        // Disable reservations for guests
        reservationsNavBtn.classList.add('disabled');
        reservationsNavBtn.onclick = () => alert('Access restricted. Only teachers can make reservations.');
        reservationsDashCard.classList.add('disabled');
        reservationsDashCard.onclick = () => alert('Access restricted. Only teachers can make reservations.');
    } else if (userRole === 'teacher') {
        // Disable rooms management for teachers
        roomsNavBtn.classList.add('disabled');
        roomsNavBtn.onclick = () => alert('Access restricted. Only administrators can manage rooms.');
        roomsDashCard.classList.add('disabled');
        roomsDashCard.onclick = () => alert('Access restricted. Only administrators can manage rooms.');
        
        // Enable reservations for teachers
        reservationsNavBtn.classList.remove('disabled');
        reservationsNavBtn.onclick = () => showSection('reservations');
        reservationsDashCard.classList.remove('disabled');
        reservationsDashCard.onclick = () => showSection('reservations');
    } else if (userRole === 'admin') {
        // Enable all features for admin
        roomsNavBtn.classList.remove('disabled');
        roomsNavBtn.onclick = () => showSection('rooms');
        roomsDashCard.classList.remove('disabled');
        roomsDashCard.onclick = () => showSection('rooms');
        
        reservationsNavBtn.classList.remove('disabled');
        reservationsNavBtn.onclick = () => showSection('reservations');
        reservationsDashCard.classList.remove('disabled');
        reservationsDashCard.onclick = () => showSection('reservations');
    }
}

// Navigation Functions
function showSection(sectionId) {
    // Check permissions
    if (!checkSectionPermission(sectionId)) {
        return;
    }

    // Hide all sections
    const sections = document.querySelectorAll('.section');
    sections.forEach(section => {
        section.classList.remove('active');
    });

    // Remove active class from all nav buttons
    const navButtons = document.querySelectorAll('.nav-btn');
    navButtons.forEach(btn => {
        btn.classList.remove('active');
    });

    // Show selected section
    document.getElementById(sectionId).classList.add('active');
    
    // Add active class to clicked nav button
    const activeBtn = document.querySelector(`[onclick="showSection('${sectionId}')"]`);
    if (activeBtn) {
        activeBtn.classList.add('active');
    }

    // Load section-specific data
    switch(sectionId) {
        case 'students':
            loadStudents();
            updateStudentActions();
            break;
        case 'rooms':
            loadRoomsSection();
            break;
        case 'student-finder':
            updateCurrentTime();
            break;
        case 'room-vacancy':
            loadRoomVacancy();
            updateVacancyTime();
            break;
        case 'reservations':
            loadReservationsSection();
            break;
        case 'timetable':
            loadTimetable();
            break;
    }
}

function checkSectionPermission(sectionId) {
    if (sectionId === 'rooms' && userRole !== 'admin') {
        alert('Access restricted. Only administrators can manage rooms and blocks.');
        return false;
    }
    
    if (sectionId === 'reservations' && userRole === 'guest') {
        alert('Access restricted. Only teachers can make room reservations.');
        return false;
    }
    
    return true;
}

// Student Management Functions
function updateStudentActions() {
    const actionsContainer = document.getElementById('studentActions');
    const actionsHeader = document.getElementById('studentActionsHeader');
    
    if (userRole === 'admin') {
        actionsContainer.innerHTML = `
    <button class="btn btn-primary" onclick="showAddStudentForm()">
        <i class="fas fa-plus"></i> Add Student
    </button>
    <input type="file" id="csvUpload" accept=".csv" onchange="handleCSVUpload(event)" style="display: none;">
    <button class="btn btn-secondary" onclick="document.getElementById('csvUpload').click();">
        <i class="fas fa-upload"></i> Bulk Upload CSV
    </button>
`;

        actionsHeader.style.display = 'table-cell';
    } else {
        actionsContainer.innerHTML = '';
        actionsHeader.style.display = 'none';
    }
}

function loadStudents() {
    const tbody = document.getElementById('studentsTableBody');
    tbody.innerHTML = '';

    students.forEach(student => {
        const row = document.createElement('tr');
        
        let actionsHTML = '';
        if (userRole === 'admin') {
            actionsHTML = `
                <td>
                    <button class="btn btn-secondary" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="editStudent(${student.id})">Edit</button>
                    <button class="btn btn-danger" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="deleteStudent(${student.id})">Delete</button>
                </td>
            `;
        } else {
            actionsHTML = '<td>-</td>';
        }
        
        row.innerHTML = `
            <td><strong>${student.usn}</strong></td>
            <td>${student.name}</td>
            <td>${student.department}</td>
            <td>${student.semester}</td>
            <td>${student.section}</td>
            <td>
                <div>${student.email}</div>
                <div style="color: #666; font-size: 0.9rem;">${student.phone}</div>
            </td>
            ${actionsHTML}
        `;
        tbody.appendChild(row);
    });
}

function searchStudents() {
    const searchTerm = document.getElementById('studentSearch').value.toLowerCase();
    const tbody = document.getElementById('studentsTableBody');
    tbody.innerHTML = '';

    const filteredStudents = students.filter(student => 
        student.usn.toLowerCase().includes(searchTerm) ||
        student.name.toLowerCase().includes(searchTerm) ||
        student.department.toLowerCase().includes(searchTerm)
    );

    filteredStudents.forEach(student => {
        const row = document.createElement('tr');
        
        let actionsHTML = '';
        if (userRole === 'admin') {
            actionsHTML = `
                <td>
                    <button class="btn btn-secondary" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="editStudent(${student.id})">Edit</button>
                    <button class="btn btn-danger" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="deleteStudent(${student.id})">Delete</button>
                </td>
            `;
        } else {
            actionsHTML = '<td>-</td>';
        }
        
        row.innerHTML = `
            <td><strong>${student.usn}</strong></td>
            <td>${student.name}</td>
            <td>${student.department}</td>
            <td>${student.semester}</td>
            <td>${student.section}</td>
            <td>
                <div>${student.email}</div>
                <div style="color: #666; font-size: 0.9rem;">${student.phone}</div>
            </td>
            ${actionsHTML}
        `;
        tbody.appendChild(row);
    });
}

function showAddStudentForm() {
    if (userRole !== 'admin') {
        alert('Access denied. Only administrators can add students.');
        return;
    }
    document.getElementById('addStudentForm').style.display = 'block';
}

function hideAddStudentForm() {
    document.getElementById('addStudentForm').style.display = 'none';
    document.getElementById('addStudentForm').querySelector('form').reset();
}

function addStudent(event) {
    event.preventDefault();
    
    if (userRole !== 'admin') {
        alert('Access denied. Only administrators can add students.');
        return;
    }
    
    const newStudent = {
        id: students.length + 1,
        usn: document.getElementById('usn').value,
        name: document.getElementById('studentName').value,
        email: document.getElementById('email').value,
        phone: document.getElementById('phone').value,
        department: document.getElementById('department').value,
        semester: parseInt(document.getElementById('semester').value),
        section: document.getElementById('section').value
    };

    students.push(newStudent);
    loadStudents();
    hideAddStudentForm();
    
    alert('Student added successfully!');
}

function deleteStudent(id) {
    if (userRole !== 'admin') {
        alert('Access denied. Only administrators can delete students.');
        return;
    }
    
    if (confirm('Are you sure you want to delete this student?')) {
        students = students.filter(student => student.id !== id);
        loadStudents();
        alert('Student deleted successfully!');
    }
}

// Room Management Functions
function loadRoomsSection() {
    if (userRole !== 'admin') {
        document.getElementById('roomsAccessDenied').style.display = 'block';
        document.getElementById('roomsAdminContent').style.display = 'none';
        document.getElementById('roomActions').innerHTML = '';
        return;
    }
    
    document.getElementById('roomsAccessDenied').style.display = 'none';
    document.getElementById('roomsAdminContent').style.display = 'block';
    
    // Update room actions
    document.getElementById('roomActions').innerHTML = `
        <button class="btn btn-primary" onclick="showAddRoomForm()">
            <i class="fas fa-plus"></i> Add Room
        </button>
        <button class="btn btn-secondary" onclick="showAddBlockForm()">
            <i class="fas fa-building"></i> Add Block
        </button>
    `;
    
    loadBlocks();
    loadRooms();
    populateBlockSelects();
}

function loadBlocks() {
    const container = document.getElementById('blocksContainer');
    container.innerHTML = '';

    blocks.forEach(block => {
        const blockCard = document.createElement('div');
        blockCard.className = 'block-card';
        blockCard.innerHTML = `
            <h4><i class="fas fa-building"></i> ${block.name}</h4>
            <p>${block.description}</p>
            <div style="margin-top: 1rem; color: #666;">
                <small>Floors: ${block.floors}</small>
            </div>
        `;
        container.appendChild(blockCard);
    });
}

function loadRooms() {
    const tbody = document.getElementById('roomsTableBody');
    tbody.innerHTML = '';

    rooms.forEach(room => {
        const row = document.createElement('tr');
        const facilities = [];
        if (room.hasProjector) facilities.push('<span class="badge badge-info">Projector</span>');
        if (room.hasAC) facilities.push('<span class="badge badge-info">AC</span>');

        row.innerHTML = `
            <td><strong>${room.roomNumber}</strong></td>
            <td>${room.block}</td>
            <td>${room.floor}</td>
            <td><span class="badge badge-success">${room.type.replace('_', ' ')}</span></td>
            <td>${room.capacity}</td>
            <td>${facilities.join(' ')}</td>
            <td>
                <button class="btn btn-secondary" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="editRoom(${room.id})">Edit</button>
                <button class="btn btn-danger" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="deleteRoom(${room.id})">Delete</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

function populateBlockSelects() {
    const selects = ['roomBlock', 'blockFilter', 'reservationBlock'];
    
    selects.forEach(selectId => {
        const select = document.getElementById(selectId);
        if (select) {
            // Clear existing options except the first one
            while (select.children.length > 1) {
                select.removeChild(select.lastChild);
            }
            
            blocks.forEach(block => {
                const option = document.createElement('option');
                option.value = block.name;
                option.textContent = block.name;
                select.appendChild(option);
            });
        }
    });
}

function showAddBlockForm() {
    document.getElementById('addBlockForm').style.display = 'block';
}

function hideAddBlockForm() {
    document.getElementById('addBlockForm').style.display = 'none';
    document.getElementById('addBlockForm').querySelector('form').reset();
}

function addBlock(event) {
    event.preventDefault();
    
    const newBlock = {
        id: blocks.length + 1,
        name: document.getElementById('blockName').value,
        floors: parseInt(document.getElementById('floors').value),
        description: document.getElementById('blockDescription').value
    };

    blocks.push(newBlock);
    loadBlocks();
    populateBlockSelects();
    hideAddBlockForm();
    
    alert('Block added successfully!');
}

function showAddRoomForm() {
    document.getElementById('addRoomForm').style.display = 'block';
}

function hideAddRoomForm() {
    document.getElementById('addRoomForm').style.display = 'none';
    document.getElementById('addRoomForm').querySelector('form').reset();
}

function addRoom(event) {
    event.preventDefault();
    
    const newRoom = {
        id: rooms.length + 1,
        roomNumber: document.getElementById('roomNumber').value,
        block: document.getElementById('roomBlock').value,
        floor: parseInt(document.getElementById('floor').value),
        type: document.getElementById('roomType').value,
        capacity: parseInt(document.getElementById('capacity').value),
        hasProjector: document.getElementById('hasProjector').checked,
        hasAC: document.getElementById('hasAC').checked
    };

    rooms.push(newRoom);
    loadRooms();
    hideAddRoomForm();
    
    alert('Room added successfully!');
}

// Student Finder Functions
function updateCurrentTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    });
    
    const timeElements = document.querySelectorAll('#currentTime, #vacancyCurrentTime');
    timeElements.forEach(element => {
        if (element) element.textContent = timeString;
    });
}

function findStudent() {
    const usn = document.getElementById('searchUSN').value.toUpperCase();
    const resultDiv = document.getElementById('studentResult');
    
    if (!usn) {
        alert('Please enter a USN');
        return;
    }

    const student = students.find(s => s.usn === usn);
    
    if (!student) {
        resultDiv.innerHTML = `
            <div style="text-align: center; padding: 2rem; background: #f8d7da; border-radius: 10px; color: #721c24;">
                <h3>Student Not Found</h3>
                <p>No student found with USN: ${usn}</p>
            </div>
        `;
        resultDiv.style.display = 'block';
        return;
    }

    // Find current class
    const now = new Date();
    const currentDay = now.toLocaleDateString('en-US', { weekday: 'long' });
    const currentTime = now.getHours() * 60 + now.getMinutes();

    const currentClass = timetable.find(t => 
        t.department === student.department &&
        t.semester === student.semester &&
        t.section === student.section &&
        t.day === currentDay &&
        isTimeBetween(currentTime, t.startTime, t.endTime)
    );

    // Find next class
    const nextClass = timetable.find(t => 
        t.department === student.department &&
        t.semester === student.semester &&
        t.section === student.section &&
        t.day === currentDay &&
        timeToMinutes(t.startTime) > currentTime
    );

    let locationHTML = '';
    
    if (currentClass) {
        locationHTML = `
            <div class="location-card current">
                <h4><i class="fas fa-map-marker-alt"></i> Current Location</h4>
                <div class="student-info">
                    <div class="info-item">
                        <div class="info-label">Subject</div>
                        <div class="info-value">${currentClass.subject}</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Room & Block</div>
                        <div class="info-value">${currentClass.room}, ${currentClass.block}</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Time</div>
                        <div class="info-value">${formatTime(currentClass.startTime)} - ${formatTime(currentClass.endTime)}</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Teacher</div>
                        <div class="info-value">${currentClass.teacher}</div>
                    </div>
                </div>
                <span class="badge badge-success">Currently in Class</span>
            </div>
        `;
        
        if (nextClass) {
            locationHTML += `
                <div class="location-card next">
                    <h4><i class="fas fa-clock"></i> Next Class</h4>
                    <div class="student-info">
                        <div class="info-item">
                            <div class="info-label">Subject</div>
                            <div class="info-value">${nextClass.subject}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Room & Block</div>
                            <div class="info-value">${nextClass.room}, ${nextClass.block}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Time</div>
                            <div class="info-value">${formatTime(nextClass.startTime)} - ${formatTime(nextClass.endTime)}</div>
                        </div>
                    </div>
                </div>
            `;
        }
    } else {
        locationHTML = `
            <div class="location-card none">
                <div style="text-align: center;">
                    <h4>No Current Class</h4>
                    <p>Student is not in any scheduled class right now</p>
                </div>
            </div>
        `;
    }

    resultDiv.innerHTML = `
        <h3><i class="fas fa-user"></i> Student Information</h3>
        <div class="student-info">
            <div class="info-item">
                <div class="info-label">Name</div>
                <div class="info-value">${student.name}</div>
            </div>
            <div class="info-item">
                <div class="info-label">USN</div>
                <div class="info-value">${student.usn}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Department</div>
                <div class="info-value">${student.department}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Semester & Section</div>
                <div class="info-value">${student.semester} Semester, Section ${student.section}</div>
            </div>
        </div>
        ${locationHTML}
    `;
    
    resultDiv.style.display = 'block';
}

// Room Vacancy Functions
function loadRoomVacancy() {
    updateVacancyStats();
    displayRoomVacancy();
}

function updateVacancyStats() {
    const now = new Date();
    const currentDay = now.toLocaleDateString('en-US', { weekday: 'long' });
    const currentTime = now.getHours() * 60 + now.getMinutes();

    let vacantCount = 0;
    let occupiedCount = 0;

    rooms.forEach(room => {
        const isOccupied = timetable.some(t => 
            t.room === room.roomNumber &&
            t.day === currentDay &&
            isTimeBetween(currentTime, t.startTime, t.endTime)
        );

        if (isOccupied) {
            occupiedCount++;
        } else {
            vacantCount++;
        }
    });

    document.getElementById('vacantCount').textContent = vacantCount;
    document.getElementById('occupiedCount').textContent = occupiedCount;
    document.getElementById('totalCount').textContent = rooms.length;
}

function displayRoomVacancy() {
    const container = document.getElementById('roomVacancyList');
    const blockFilter = document.getElementById('blockFilter').value;
    
    const now = new Date();
    const currentDay = now.toLocaleDateString('en-US', { weekday: 'long' });
    const currentTime = now.getHours() * 60 + now.getMinutes();

    let filteredRooms = rooms;
    if (blockFilter !== 'all') {
        filteredRooms = rooms.filter(room => room.block === blockFilter);
    }

    container.innerHTML = '';

    filteredRooms.forEach(room => {
        const currentClass = timetable.find(t => 
            t.room === room.roomNumber &&
            t.day === currentDay &&
            isTimeBetween(currentTime, t.startTime, t.endTime)
        );

        const nextClass = timetable.find(t => 
            t.room === room.roomNumber &&
            t.day === currentDay &&
            timeToMinutes(t.startTime) > currentTime
        );

        const isOccupied = !!currentClass;

        const roomItem = document.createElement('div');
        roomItem.className = `room-vacancy-item ${isOccupied ? 'occupied' : 'available'}`;

        let statusHTML = '';
        if (currentClass) {
            statusHTML = `
                <div style="font-size: 0.9rem;">
                    <strong>Current Class:</strong> ${currentClass.subject}<br>
                    <strong>Teacher:</strong> ${currentClass.teacher}<br>
                    <strong>Time:</strong> ${formatTime(currentClass.startTime)} - ${formatTime(currentClass.endTime)}
                </div>
            `;
        } else if (nextClass) {
            statusHTML = `
                <div style="font-size: 0.9rem; color: #666;">
                    <strong>Next Class:</strong> ${nextClass.subject}<br>
                    <strong>Time:</strong> ${formatTime(nextClass.startTime)} - ${formatTime(nextClass.endTime)}
                </div>
            `;
        } else {
            statusHTML = '<div style="color: #666;">No scheduled classes</div>';
        }

        roomItem.innerHTML = `
            <div class="room-info">
                <h4>${room.roomNumber} - ${room.block}</h4>
                <div class="room-details">
                    ${room.type.replace('_', ' ')} | Capacity: ${room.capacity}
                    ${room.hasProjector ? ' | Projector' : ''}
                    ${room.hasAC ? ' | AC' : ''}
                </div>
                ${statusHTML}
            </div>
            <div class="room-status">
                <span class="badge ${isOccupied ? 'badge-danger' : 'badge-success'}">
                    ${isOccupied ? 'Occupied' : 'Available'}
                </span>
            </div>
        `;

        container.appendChild(roomItem);
    });
}

function filterRoomVacancy() {
    displayRoomVacancy();
    updateVacancyStats();
}

function updateVacancyTime() {
    updateCurrentTime();
    setInterval(updateCurrentTime, 1000);
}

// Reservation Functions
function loadReservationsSection() {
    if (userRole === 'guest') {
        document.getElementById('reservationsAccessDenied').style.display = 'block';
        document.getElementById('reservationsTeacherContent').style.display = 'none';
        return;
    }
    
    document.getElementById('reservationsAccessDenied').style.display = 'none';
    document.getElementById('reservationsTeacherContent').style.display = 'block';
    
    populateReservationBlocks();
    loadMyReservations();
}

function populateReservationBlocks() {
    const select = document.getElementById('reservationBlock');
    if (select) {
        // Clear existing options except the first one
        while (select.children.length > 1) {
            select.removeChild(select.lastChild);
        }
        
        blocks.forEach(block => {
            const option = document.createElement('option');
            option.value = block.name;
            option.textContent = block.name;
            select.appendChild(option);
        });
    }
}

function checkAvailability() {
    const block = document.getElementById('reservationBlock').value;
    const date = document.getElementById('reservationDate').value;
    const startTime = document.getElementById('startTime').value;
    const endTime = document.getElementById('endTime').value;

    if (!date || !startTime || !endTime) {
        alert('Please select date and time to check availability');
        return;
    }

    if (startTime >= endTime) {
        alert('End time must be after start time');
        return;
    }

    const selectedDate = new Date(date);
    const dayOfWeek = selectedDate.toLocaleDateString('en-US', { weekday: 'long' });
    
    let filteredRooms = rooms;
    if (block !== 'all') {
        filteredRooms = rooms.filter(room => room.block === block);
    }

    const availableRoomsContainer = document.getElementById('availableRooms');
    availableRoomsContainer.innerHTML = '';

    const headerDiv = document.createElement('div');
    headerDiv.innerHTML = `
        <h3><i class="fas fa-check-circle"></i> Available Rooms - ${formatDate(date)} (${formatTime(startTime)} - ${formatTime(endTime)})</h3>
    `;
    availableRoomsContainer.appendChild(headerDiv);

    let availableCount = 0;

    filteredRooms.forEach(room => {
        // Check against timetable
        const conflictingClass = timetable.find(t => 
            t.room === room.roomNumber &&
            t.day === dayOfWeek &&
            isTimeConflict(startTime, endTime, t.startTime, t.endTime)
        );

        // Check against reservations
        const conflictingReservation = reservations.find(r => 
            r.roomNumber === room.roomNumber &&
            r.date === date &&
            r.status === 'confirmed' &&
            isTimeConflict(startTime, endTime, r.startTime, r.endTime)
        );

        const isAvailable = !conflictingClass && !conflictingReservation;

        if (isAvailable) {
            availableCount++;
            
            const roomItem = document.createElement('div');
            roomItem.className = 'available-room-item';

            roomItem.innerHTML = `
                <div class="room-details">
                    <h4>${room.roomNumber} - ${room.block}</h4>
                    <p><span class="badge badge-info">${room.type.replace('_', ' ')}</span> | Capacity: ${room.capacity}</p>
                    <p>Facilities: ${room.hasProjector ? 'Projector' : ''} ${room.hasAC ? 'AC' : ''}</p>
                </div>
                <div class="reserve-actions">
                    <button class="instant-reserve-btn" onclick="instantReserve('${room.roomNumber}', '${room.block}', '${date}', '${startTime}', '${endTime}')">
                        <i class="fas fa-bolt"></i> Reserve Now
                    </button>
                </div>
            `;

            availableRoomsContainer.appendChild(roomItem);
        }
    });

    if (availableCount === 0) {
        availableRoomsContainer.innerHTML += `
            <div style="text-align: center; padding: 2rem; background: #fff3cd; border-radius: 10px; color: #856404;">
                <h4>No Available Rooms</h4>
                <p>All rooms in the selected block are occupied during this time slot.</p>
                <p>Please try a different time or block.</p>
            </div>
        `;
    }

    availableRoomsContainer.style.display = 'block';
}

function instantReserve(roomNumber, block, date, startTime, endTime) {
    const purpose = prompt('Please enter the purpose of this reservation:');
    
    if (!purpose || purpose.trim() === '') {
        alert('Purpose is required for reservation');
        return;
    }

    const newReservation = {
        id: reservations.length + 1,
        roomNumber: roomNumber,
        block: block,
        teacherName: currentUser.name,
        teacherId: currentUser.id,
        date: date,
        startTime: startTime,
        endTime: endTime,
        purpose: purpose.trim(),
        status: 'confirmed'
    };

    reservations.push(newReservation);
    
    // Hide available rooms and refresh reservations
    document.getElementById('availableRooms').style.display = 'none';
    loadMyReservations();
    
    // Clear form
    document.getElementById('reservationDate').value = '';
    document.getElementById('startTime').value = '';
    document.getElementById('endTime').value = '';
    
    alert(`Room ${roomNumber} reserved successfully!\n\nDetails:\nDate: ${formatDate(date)}\nTime: ${formatTime(startTime)} - ${formatTime(endTime)}\nPurpose: ${purpose}`);
}

function loadMyReservations() {
    const tbody = document.getElementById('reservationsTableBody');
    tbody.innerHTML = '';

    // Filter reservations for current teacher (or show all for admin)
    let userReservations = reservations;
    if (userRole === 'teacher') {
        userReservations = reservations.filter(r => r.teacherId === currentUser.id);
    }

    userReservations.forEach(reservation => {
        const row = document.createElement('tr');
        
        let statusClass = '';
        switch(reservation.status) {
            case 'confirmed': statusClass = 'badge-success'; break;
            case 'cancelled': statusClass = 'badge-danger'; break;
            case 'pending': statusClass = 'badge-warning'; break;
        }

        let actionsHTML = '';
        if (reservation.status === 'confirmed' && (userRole === 'admin' || reservation.teacherId === currentUser.id)) {
            actionsHTML = `
                <button class="btn btn-danger" style="padding: 0.3rem 0.8rem; font-size: 0.8rem;" onclick="cancelReservation(${reservation.id})">Cancel</button>
            `;
        } else {
            actionsHTML = '-';
        }

        row.innerHTML = `
            <td>
                <strong>${reservation.roomNumber}</strong><br>
                <small style="color: #666;">${reservation.block}</small>
            </td>
            <td>
                <strong>${formatDate(reservation.date)}</strong><br>
                <small>${formatTime(reservation.startTime)} - ${formatTime(reservation.endTime)}</small>
            </td>
            <td style="max-width: 200px; word-wrap: break-word;">${reservation.purpose}</td>
            <td><span class="badge ${statusClass}">${reservation.status.toUpperCase()}</span></td>
            <td>${actionsHTML}</td>
        `;
        tbody.appendChild(row);
    });

    if (userReservations.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td colspan="5" style="text-align: center; color: #666; font-style: italic;">
                No reservations found
            </td>
        `;
        tbody.appendChild(row);
    }
}

function cancelReservation(id) {
    if (confirm('Are you sure you want to cancel this reservation?')) {
        const reservation = reservations.find(r => r.id === id);
        if (reservation) {
            reservation.status = 'cancelled';
            loadMyReservations();
            alert('Reservation cancelled successfully!');
        }
    }
}

// Timetable Functions
function loadTimetable() {
    const department = document.getElementById('timetableDepartment').value;
    const semester = parseInt(document.getElementById('timetableSemester').value);
    const section = document.getElementById('timetableSection').value;

    const filteredTimetable = timetable.filter(t => 
        t.department === department && 
        t.semester === semester && 
        t.section === section
    );

    const timetableGrid = document.getElementById('timetableGrid');
    
    const timeSlots = [
        '09:00-10:00', '10:00-11:00', '11:00-12:00', '12:00-13:00',
        '14:00-15:00', '15:00-16:00', '16:00-17:00'
    ];
    
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    let tableHTML = `
        <table class="timetable-table">
            <thead>
                <tr>
                    <th style="width: 120px;">Time</th>
                    ${days.map(day => `<th>${day}</th>`).join('')}
                </tr>
            </thead>
            <tbody>
    `;

    timeSlots.forEach(timeSlot => {
        const [startTime] = timeSlot.split('-');
        tableHTML += `<tr>`;
        tableHTML += `<td class="time-slot"><i class="fas fa-clock"></i> ${formatTimeSlot(timeSlot)}</td>`;
        
        days.forEach(day => {
            const classEntry = filteredTimetable.find(t => 
                t.day === day && t.startTime === startTime
            );
            
            if (classEntry) {
                tableHTML += `
                    <td>
                        <div class="class-slot">
                            <div class="class-subject">${classEntry.subject}</div>
                            <div class="class-teacher">${classEntry.teacher}</div>
                            <div class="class-room">${classEntry.room}, ${classEntry.block}</div>
                        </div>
                    </td>
                `;
            } else {
                tableHTML += `<td><div class="free-slot">Free</div></td>`;
            }
        });
        
        tableHTML += `</tr>`;
    });

    tableHTML += `</tbody></table>`;
    timetableGrid.innerHTML = tableHTML;
}

function filterTimetable() {
    loadTimetable();
}

// Utility Functions
function formatTime(timeString) {
    const [hours, minutes] = timeString.split(':');
    const hour = parseInt(hours);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 || 12;
    return `${displayHour}:${minutes} ${ampm}`;
}

function formatTimeSlot(timeSlot) {
    const [start, end] = timeSlot.split('-');
    return `${formatTime(start)} - ${formatTime(end)}`;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        weekday: 'short',
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function timeToMinutes(timeString) {
    const [hours, minutes] = timeString.split(':').map(Number);
    return hours * 60 + minutes;
}

function isTimeBetween(currentMinutes, startTime, endTime) {
    const start = timeToMinutes(startTime);
    const end = timeToMinutes(endTime);
    return currentMinutes >= start && currentMinutes < end;
}

function isTimeConflict(start1, end1, start2, end2) {
    const startTime1 = timeToMinutes(start1);
    const endTime1 = timeToMinutes(end1);
    const startTime2 = timeToMinutes(start2);
    const endTime2 = timeToMinutes(end2);

    return startTime1 < endTime2 && endTime1 > startTime2;
}

function getTodayDate() {
    return new Date().toISOString().split('T')[0];
}

// Initialize the application
function initializeApp() {
    // Set minimum date for reservations to today
    const dateInput = document.getElementById('reservationDate');
    if (dateInput) {
        dateInput.min = getTodayDate();
    }

    // Load initial data
    loadStudents();
    updateStudentActions();
    populateBlockSelects();
    updateCurrentTime();
    
    // Update time every second
    setInterval(updateCurrentTime, 1000);
    
    // Show dashboard by default
    showSection('dashboard');
}

document.addEventListener('DOMContentLoaded', function() {
    // Show login screen by default
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
});