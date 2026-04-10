console.log('WALLET UI LOADED');
let licenses = [];
let contextMenu = null;
let contextLicense = null;
let carkeys = [];

window.addEventListener('message', function(event) {
    console.log('NUI MESSAGE:', event.data); // Debug print
    const data = event.data;
    if (data.action === 'open') {
        showWallet(data);
    } else if (data.action === 'updateLicenses') {
        licenses = data.licenses || [];
        renderLicenses();
    } else if (data.action === 'updateCarKeys') {
        carkeys = data.carkeys || [];
        renderCarkeys();
    } else if (data.action === 'showLicense') {
        showOverlay(data.license, data.from);
    } else if (data.action === 'close') {
        hideWallet();
        hideOverlay();
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    } else if (data.action === 'openKeymacher') {
        document.getElementById('walletUI').style.display = 'block';
        keymacherTab.click();
    } else if (data.action === 'setKeymacherVehicles') {
        renderKeymacherList(data.vehicles || []);
    } else if (data.action === 'keymacherFeedback') {
        document.getElementById('keymacherFeedback').innerText = data.msg;
        document.getElementById('keymacherFeedback').style.color = data.type === 'error' ? '#ff3333' : '#FFD700';
    }
});

function showWallet(data) {
    console.log('showWallet called', data); // Debug print
    const walletUI = document.getElementById('walletUI');
    walletUI.style.display = 'block';
    
    // Hauptdaten setzen
    document.getElementById('name').textContent = data.name || '-';
    document.getElementById('birthdate').textContent = data.birthdate || '-';
    document.getElementById('joindate').textContent = data.joindate || '-';
    document.getElementById('height').textContent = (data.height ? data.height + ' cm' : '-');
    document.getElementById('citizenid').textContent = data.citizenid || '-';
    document.getElementById('hungerBar').style.width = (data.hunger || 0) + '%';
    document.getElementById('thirstBar').style.width = (data.thirst || 0) + '%';
    
    // Listen initialisieren
    licenses = data.licenses || [];
    carkeys = data.carkeys || [];
    renderLicenses();
    renderCarkeys();
    
    // Close Button
    document.getElementById('closeBtn').onclick = function() {
        hideWallet();
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    };
}

function hideWallet() {
    console.log('hideWallet called'); // Debug print
    document.getElementById('walletUI').style.display = 'none';
}

function renderLicenses() {
    const list = document.getElementById('licensesList');
    list.innerHTML = '';
    if (!licenses.length) {
        list.innerHTML = '<div style="color:#888;">Keine Lizenzen oder Dokumente vorhanden.</div>';
        return;
    }
    
    licenses.forEach(lic => {
        const div = document.createElement('div');
        div.className = 'license-item';
        let displayLabel = lic.label || lic.type;
        let licenseType = 'Lizenz';
        
        // Fahrzeugpapier: Label aus JSON holen oder Kennzeichen aus Typ extrahieren
        if (lic.type && lic.type.startsWith('fahrzeugpapier_')) {
            let kennzeichen = lic.type.replace('fahrzeugpapier_', '');
            licenseType = 'Fahrzeugpapier';
            try {
                let l = lic.label;
                if (typeof l === 'string') l = JSON.parse(l);
                if (l && typeof l === 'object' && l.label) displayLabel = l.label;
                else displayLabel = 'Fahrzeugpapier ' + kennzeichen;
            } catch(e) {
                displayLabel = 'Fahrzeugpapier ' + kennzeichen;
            }
        }
        
        div.innerHTML = `
            <div class="license-info">
                <span class="license-label">${displayLabel}</span>
                <span class="license-type">${licenseType}</span>
            </div>
        `;
        
        // Rechtsklick und normaler Klick für alle Lizenzen und Papiere
        div.oncontextmenu = function(e) {
            e.preventDefault();
            showContextMenu(e.pageX, e.pageY, lic);
        };
        div.onclick = function(e) {
            if (e.button === 0) { // Linksklick
                if (lic.type && lic.type.startsWith('fahrzeugpapier_')) {
                    showOverlay(lic);
                } else {
                    showContextMenu(e.pageX, e.pageY, lic);
                }
            }
        };
        list.appendChild(div);
    });
}

function renderCarkeys() {
    const list = document.getElementById('carkeysList');
    list.innerHTML = '';
    if (!carkeys || !carkeys.length) {
        list.innerHTML = '<div style="color:#888;">Keine Fahrzeugschlüssel vorhanden.</div>';
        return;
    }
    
    console.log('Rendering car keys:', carkeys); // Debug-Ausgabe
    
    carkeys.forEach(key => {
        const div = document.createElement('div');
        div.className = 'carkey-item';
        const modelName = key.model || 'Unbekannt';
        
        // Debug-Ausgabe für jeden Schlüssel
        console.log('Key before render:', {
            plate: key.plate,
            model: key.model,
            is_original: key.is_original,
            is_copy: key.is_copy
        });
        
        // Korrigierte Logik für die Anzeige
        const displayType = key.is_original ? 'Original' : 'Kopie';
        const cssClass = key.is_original ? 'original' : 'copy';
        
        div.innerHTML = `
            <div class="carkey-info">
                <span class="carkey-label">${modelName}</span>
                <span class="key-type ${cssClass}">${displayType}</span>
            </div>
            <span class="carkey-plate">${key.plate}</span>
        `;
        
        // Rechtsklick und normaler Klick für Schlüssel
        div.oncontextmenu = function(e) {
            e.preventDefault();
            showContextMenuCarkey(e.pageX, e.pageY, key, key.is_original);
        };
        div.onclick = function(e) {
            if (e.button === 0) { // Linksklick
                showContextMenuCarkey(e.pageX, e.pageY, key, key.is_original);
            }
        };
        list.appendChild(div);
    });
}

// Tab-Wechsel
document.getElementById('tab-licenses').onclick = function() {
    document.getElementById('tab-licenses').classList.add('active');
    document.getElementById('tab-carkeys').classList.remove('active');
    document.getElementById('tabContent-licenses').style.display = 'block';
    document.getElementById('tabContent-carkeys').style.display = 'none';
    document.getElementById('tabContent-licenses').classList.add('active');
    document.getElementById('tabContent-carkeys').classList.remove('active');
};

document.getElementById('tab-carkeys').onclick = function() {
    document.getElementById('tab-carkeys').classList.add('active');
    document.getElementById('tab-licenses').classList.remove('active');
    document.getElementById('tabContent-carkeys').style.display = 'block';
    document.getElementById('tabContent-licenses').style.display = 'none';
    document.getElementById('tabContent-carkeys').classList.add('active');
    document.getElementById('tabContent-licenses').classList.remove('active');
};

function showContextMenu(x, y, license) {
    hideContextMenu();
    contextLicense = license;
    contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu';
    contextMenu.style.left = x + 'px';
    contextMenu.style.top = y + 'px';
    
    // Button: Selbst zeigen
    const btn1 = document.createElement('button');
    btn1.className = 'context-menu-btn';
    btn1.textContent = 'Selbst zeigen';
    btn1.onclick = function() { sendLicenseAction('showSelf'); };
    
    // Button: Nächstem Spieler zeigen
    const btn2 = document.createElement('button');
    btn2.className = 'context-menu-btn';
    btn2.textContent = 'Nächstem Spieler zeigen';
    btn2.onclick = function() { sendLicenseAction('showOther'); };
    
    contextMenu.appendChild(btn1);
    contextMenu.appendChild(btn2);
    document.body.appendChild(contextMenu);
    document.addEventListener('mousedown', contextMenuListener);
}

function showContextMenuCarkey(x, y, key, isOriginal) {
    hideContextMenu();
    contextMenu = document.createElement('div');
    contextMenu.className = 'context-menu';
    contextMenu.style.left = x + 'px';
    contextMenu.style.top = y + 'px';
    
    if (isOriginal) {
        const btn = document.createElement('button');
        btn.className = 'context-menu-btn';
        btn.textContent = 'Originalschlüssel kann nicht übergeben werden';
        btn.style.color = '#888';
        btn.style.cursor = 'not-allowed';
        contextMenu.appendChild(btn);
    } else {
        const btn = document.createElement('button');
        btn.className = 'context-menu-btn';
        btn.textContent = 'An nächsten Spieler übergeben';
        btn.onclick = function() {
            console.log('Transferring key:', key.plate);
            $.post(`https://${GetParentResourceName()}/giveCarKey`, JSON.stringify({
                plate: key.plate
            }));
            hideContextMenu();
        };
        contextMenu.appendChild(btn);
    }
    
    document.body.appendChild(contextMenu);
    document.addEventListener('mousedown', contextMenuListener);
}

function hideContextMenu() {
    if (contextMenu) {
        document.body.removeChild(contextMenu);
        contextMenu = null;
    }
    document.removeEventListener('mousedown', contextMenuListener);
}

function contextMenuListener(e) {
    if (contextMenu && !contextMenu.contains(e.target)) hideContextMenu();
}

function sendLicenseAction(action) {
    if (!contextLicense) return;
    fetch(`https://${GetParentResourceName()}/licenseAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: action, license: contextLicense })
    });
    hideContextMenu();
}

function showOverlay(license, from) {
    // Wenn Fahrzeugpapier, Wallet-UI ausblenden
    if (license.type && license.type.startsWith('fahrzeugpapier_')) {
        document.getElementById('walletUI').style.display = 'none';
        let data = {}, label = '';
        try {
            const l = JSON.parse(license.label);
            data = l.data || {};
            label = l.label || '';
        } catch(e) {}
        
        document.getElementById('overlay-license').style.display = 'flex';
        const content = document.querySelector('#overlay-license .overlay-content');
        content.innerHTML = `
            <div class="vehicle-paper">
                <div class="vehicle-paper-header">${label}</div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Inhaber</span>
                    <span class="vehicle-paper-value">${data.inhaber || '-'}</span>
                </div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Anmeldedatum</span>
                    <span class="vehicle-paper-value">${data.anmeldedatum || '-'}</span>
                </div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Erstanmeldedatum</span>
                    <span class="vehicle-paper-value">${data.erstanmeldedatum || '-'}</span>
                </div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Baujahr</span>
                    <span class="vehicle-paper-value">${data.baujahr || '-'}</span>
                </div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Modell</span>
                    <span class="vehicle-paper-value">${data.modell || '-'}</span>
                </div>
                
                <div class="vehicle-paper-row">
                    <span class="vehicle-paper-label">Kraftstoffart</span>
                    <span class="vehicle-paper-value">${data.kraftstoffart || '-'}</span>
                </div>
                
                <button class="close-btn" onclick="hideOverlay()">×</button>
            </div>
        `;
    } else {
        // Standard-Lizenz-Overlay
        document.getElementById('walletUI').style.display = 'block';
        document.getElementById('overlayLicenseTitle').textContent = from ? `Lizenz von ${from}` : 'Lizenz';
        document.getElementById('overlayLicenseLabel').textContent = license.label || license.type;
        document.getElementById('overlay-license').style.display = 'flex';
    }
}

function hideOverlay() {
    document.getElementById('overlay-license').style.display = 'none';
}

// ESC schließt das UI
window.onkeydown = function(e) {
    if (e.key === 'Escape') {
        hideWallet();
        hideOverlay();
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    }
};

// Aktualisiere Fahrzeugschlüssel
function updateCarKeys(keys) {
    console.log('Aktualisiere Schlüssel:', keys);
    const container = $('#carkeys-container');
    container.empty();
    
    if (!keys || keys.length === 0) {
        container.html('<div class="no-keys">Keine Fahrzeugschlüssel vorhanden.</div>');
        return;
    }
    
    keys.forEach(key => {
        const item = document.createElement('div');
        item.className = 'carkey-item';
        item.dataset.plate = key.plate;
        item.innerHTML = `
            <div class="key-info">
                <span class="key-model">${key.model}</span>
                <span class="key-plate">${key.plate}</span>
                <span class="key-type ${key.is_original ? 'original' : 'copy'}">${key.is_original ? 'Original' : 'Kopie'}</span>
            </div>
        `;
        container.append(item);
    });
} 