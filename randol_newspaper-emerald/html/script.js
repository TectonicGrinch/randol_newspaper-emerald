let currentData = null;
let isClockedIn = false;
let isOutOfPapers = false;

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'open') {
        currentData = data.data;
        isClockedIn = data.clockedIn;
        isOutOfPapers = data.outOfPapers;
        openMenu();
    } else if (data.action === 'hide') {
        document.getElementById('container').style.display = 'none';
    }
});

function openMenu() {
    if (!currentData) return;
    
    const container = document.getElementById('container');
    container.style.display = 'flex';
    
    // Update player level and EXP
    document.getElementById('playerLevel').textContent = currentData.level;
    
    const expPercent = (currentData.exp / currentData.nextLevelExp) * 100;
    document.getElementById('expFill').style.width = expPercent + '%';
    document.getElementById('expText').textContent = `${currentData.exp} / ${currentData.nextLevelExp} EXP`;
    
    // Update stats
    document.getElementById('totalMoney').textContent = '$' + currentData.totalMoney.toLocaleString();
    document.getElementById('routesCompleted').textContent = currentData.routesCompleted;
    document.getElementById('papersDelivered').textContent = currentData.papersDelivered;
    document.getElementById('papersMissed').textContent = currentData.papersMissed;
    document.getElementById('currentVehicle').textContent = capitalizeFirst(currentData.currentVehicle);
    
    // Render routes
    renderRoutes();
    
    // Render leaderboard
    renderLeaderboard();
    
    // Show/hide action buttons
    updateActionButtons();
}

function renderLeaderboard() {
    const leaderboardList = document.getElementById('leaderboardList');
    const leaderboardRank = document.getElementById('leaderboardRank');
    leaderboardList.innerHTML = '';
    
    if (!currentData.leaderboard || currentData.leaderboard.length === 0) {
        leaderboardList.innerHTML = '<div style="text-align: center; color: rgba(0,0,0,0.5); padding: 20px;">No data yet</div>';
        leaderboardRank.textContent = 'Your Rank: Unranked';
        return;
    }
    
    // Only show top 3
    const topThree = currentData.leaderboard.slice(0, 3);
    
    topThree.forEach((entry, index) => {
        const rank = index + 1;
        const entryDiv = document.createElement('div');
        entryDiv.className = 'leaderboard-entry';
        
        if (rank === 1) entryDiv.classList.add('rank-1');
        else if (rank === 2) entryDiv.classList.add('rank-2');
        else if (rank === 3) entryDiv.classList.add('rank-3');
        
        let rankDisplay = `#${rank}`;
        if (rank === 1) rankDisplay = '🥇';
        else if (rank === 2) rankDisplay = '🥈';
        else if (rank === 3) rankDisplay = '🥉';
        
        entryDiv.innerHTML = `
            <span class="leaderboard-rank">${rankDisplay}</span>
            <span class="leaderboard-name">${entry.character_name}</span>
            <span class="leaderboard-papers">${entry.papers_delivered.toLocaleString()} papers</span>
        `;
        
        leaderboardList.appendChild(entryDiv);
    });
    
    // Find player's rank
    const playerRank = currentData.leaderboard.findIndex(entry => 
        entry.papers_delivered === currentData.papersDelivered
    ) + 1;
    
    if (playerRank > 0) {
        leaderboardRank.textContent = `Your Rank: #${playerRank}`;
    } else {
        leaderboardRank.textContent = 'Your Rank: Unranked';
    }
}

function renderRoutes() {
    const routesList = document.getElementById('routesList');
    routesList.innerHTML = '';
    
    // Filter only unlocked routes
    const unlockedRoutes = currentData.routes.filter(route => !route.locked);
    const totalRoutes = currentData.routes.length;
    
    // Update counter
    document.getElementById('routesCount').textContent = `${unlockedRoutes.length}/${totalRoutes}`;
    
    // Only render unlocked routes
    unlockedRoutes.forEach(route => {
        const routeCard = document.createElement('div');
        routeCard.className = 'route-card';
        
        routeCard.innerHTML = `
            <div class="route-header">
                <span class="route-name">${route.name}</span>
                <span class="route-level">Level ${route.requiredLevel}</span>
            </div>
            <div class="route-details">
                <span>📍 ${route.locations} Locations</span>
                <span>💰 ${route.payout.min}-${route.payout.max} per delivery</span>
            </div>
        `;
        
        if (!isClockedIn) {
            routeCard.style.cursor = 'pointer';
            routeCard.addEventListener('click', function() {
                startRoute(route.id);
            });
        }
        
        routesList.appendChild(routeCard);
    });
    
    // Show message if no routes unlocked
    if (unlockedRoutes.length === 0) {
        routesList.innerHTML = '<div style="text-align: center; color: #666; padding: 20px;">Complete deliveries to unlock routes!</div>';
    }
}

function updateActionButtons() {
    const restockBtn = document.getElementById('restockBtn');
    const completeBtn = document.getElementById('completeBtn');
    
    if (isClockedIn && isOutOfPapers) {
        restockBtn.classList.remove('hidden');
    } else {
        restockBtn.classList.add('hidden');
    }
    
    if (isClockedIn) {
        completeBtn.classList.remove('hidden');
    } else {
        completeBtn.classList.add('hidden');
    }
}

function startRoute(routeId) {
    if (isClockedIn) return;
    
    console.log('Starting route:', routeId);
    
    fetch(`https://${GetParentResourceName()}/startRoute`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ routeId: routeId })
    }).then(() => {
        console.log('Route start request sent');
    });
}

function restockPapers() {
    fetch(`https://${GetParentResourceName()}/restockPapers`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function completeJob() {
    fetch(`https://${GetParentResourceName()}/completeJob`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function closeMenu() {
    console.log('Closing menu');
    const container = document.getElementById('container');
    container.style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(() => {
        console.log('Close request sent');
    });
}

function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// ESC key to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeMenu();
    }
});

// Prevent context menu
document.addEventListener('contextmenu', event => event.preventDefault());

function GetParentResourceName() {
    const resourceName = 'randol_newspaper-emerald';
    console.log('Resource name:', resourceName);
    return resourceName;
}