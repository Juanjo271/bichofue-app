ADMIN_HTML = '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bichofué Admin - Panel de Control</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #2F7D32 0%, #111111 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        header {
            background: rgba(255,255,255,0.95);
            padding: 20px 30px;
            border-radius: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.15);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        header h1 {
            color: #111111;
            font-size: 28px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .badge {
            background: #F4C400;
            color: #111111;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
        }

        /* Tabs */
        .tabs {
            display: flex;
            gap: 8px;
            margin-bottom: 20px;
            background: rgba(255,255,255,0.1);
            padding: 8px;
            border-radius: 16px;
        }
        .tab {
            padding: 12px 24px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            background: transparent;
            color: rgba(255,255,255,0.7);
            transition: all 0.3s;
        }
        .tab.active {
            background: #F4C400;
            color: #111111;
        }
        .tab:hover:not(.active) {
            background: rgba(255,255,255,0.1);
            color: white;
        }
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Stats */
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            text-align: center;
            border: 2px solid transparent;
            transition: all 0.3s;
        }
        .stat-card:hover {
            border-color: #F4C400;
            transform: translateY(-2px);
        }
        .stat-card h3 { color: #7A4A1E; font-size: 14px; margin-bottom: 8px; }
        .stat-card .number { font-size: 32px; font-weight: bold; color: #2F7D32; }

        /* Actions */
        .actions {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .btn-primary { background: #F4C400; color: #111111; }
        .btn-primary:hover { background: #E6B000; transform: translateY(-2px); box-shadow: 0 4px 12px rgba(244,196,0,0.3); }
        .btn-success { background: #2F7D32; color: white; }
        .btn-success:hover { background: #1B5E20; }
        .btn-danger { background: #7A4A1E; color: white; }
        .btn-info { background: #F6E7D8; color: #7A4A1E; }
        .btn-info:hover { background: #EBD5C0; }

        /* Tables */
        .table-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 14px 16px; text-align: left; }
        th {
            background: #F6E7D8;
            font-weight: 600;
            color: #7A4A1E;
            font-size: 13px;
            text-transform: uppercase;
        }
        tr { border-bottom: 1px solid #eee; }
        tr:hover { background: #F6E7D8; }
        .tag {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        .tag-emblematico { background: #FFF3E0; color: #E65100; }
        .tag-normal { background: #E8F5E9; color: #2F7D32; }
        .tag-comun { background: #E8F5E9; color: #2F7D32; }
        .tag-rara { background: #E3F2FD; color: #1565C0; }
        .tag-epica { background: #F3E5F5; color: #7B1FA2; }
        .tag-legendaria { background: #FFF8E1; color: #FF6F00; }
        .actions-cell { display: flex; gap: 6px; }
        .btn-small {
            padding: 6px 12px;
            font-size: 12px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
        }

        /* Image */
        .image-preview {
            max-width: 100px;
            max-height: 60px;
            border-radius: 8px;
            object-fit: cover;
            border: 2px solid #F6E7D8;
        }
        .stamp-preview {
            width: 80px;
            height: 80px;
            border-radius: 12px;
            object-fit: cover;
            border: 3px solid #F4C400;
        }

        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            z-index: 1000;
            justify-content: center;
            align-items: center;
        }
        .modal.active { display: flex; }
        .modal-content {
            background: white;
            padding: 30px;
            border-radius: 20px;
            width: 90%;
            max-width: 600px;
            max-height: 90vh;
            overflow-y: auto;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .modal-content h2 {
            color: #111111;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .form-group { margin-bottom: 16px; }
        .form-group label {
            display: block;
            margin-bottom: 6px;
            font-weight: 600;
            color: #7A4A1E;
        }
        .form-group input, .form-group textarea, .form-group select {
            width: 100%;
            padding: 10px 14px;
            border: 2px solid #F6E7D8;
            border-radius: 12px;
            font-size: 14px;
            transition: all 0.3s;
        }
        .form-group input:focus, .form-group textarea:focus, .form-group select:focus {
            outline: none;
            border-color: #F4C400;
            box-shadow: 0 0 0 3px rgba(244,196,0,0.2);
        }
        .form-group textarea { min-height: 100px; resize: vertical; }
        .checkbox-group {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 8px;
        }
        .audio-indicator {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 8px;
            background: #E3F2FD;
            color: #1565C0;
            border-radius: 8px;
            font-size: 11px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>
                <span style="font-size: 36px;">🐦</span>
                Bichofué Admin
                <span class="badge">v2.0</span>
            </h1>
            <div style="color: #7A4A1E; font-size: 14px;">
                Backend: <strong>{{ backend_ip }}</strong>:5000
            </div>
        </header>

        <!-- Tabs -->
        <div class="tabs">
            <button class="tab active" onclick="switchTab('atractivos')">🏛️ Atractivos</button>
            <button class="tab" onclick="switchTab('estampas')">🎴 Estampas</button>
        </div>

        <!-- TAB: ATRACTIVOS -->
        <div id="tab-atractivos" class="tab-content active">
            <div class="stats">
                <div class="stat-card">
                    <h3>Total Atractivos</h3>
                    <div class="number">{{ stats.total }}</div>
                </div>
                <div class="stat-card">
                    <h3>Emblemáticos</h3>
                    <div class="number">{{ stats.emblematicos }}</div>
                </div>
                <div class="stat-card">
                    <h3>Con Audio TTS</h3>
                    <div class="number">{{ stats.con_audio }}</div>
                </div>
                <div class="stat-card">
                    <h3>Con Imagen</h3>
                    <div class="number">{{ stats.con_imagen }}</div>
                </div>
            </div>

            <div class="actions">
                <button class="btn btn-primary" onclick="openModal('create')">
                    <span>+</span> Nuevo Lugar
                </button>
                <button class="btn btn-info" onclick="location.reload()">
                    <span>↻</span> Actualizar
                </button>
            </div>

            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Imagen</th>
                            <th>Nombre</th>
                            <th>Categoría</th>
                            <th>Coordenadas</th>
                            <th>Tipo</th>
                            <th>Audio</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for atr in atractivos %}
                        <tr>
                            <td>{{ atr.id }}</td>
                            <td>
                                {% if atr.url_imagen_local %}
                                <img src="{{ atr.url_imagen_local }}" class="image-preview" alt="{{ atr.nombre }}">
                                {% else %}
                                <span style="color: #999; font-size: 12px;">Sin imagen</span>
                                {% endif %}
                            </td>
                            <td><strong>{{ atr.nombre }}</strong></td>
                            <td>{{ atr.componente or atr.grupo or '-' }}</td>
                            <td>
                                {% if atr.latitud and atr.longitud %}
                                {{ "%.4f"|format(atr.latitud) }}, {{ "%.4f"|format(atr.longitud) }}
                                {% else %}
                                -
                                {% endif %}
                            </td>
                            <td>
                                {% if atr.es_emblematico %}
                                <span class="tag tag-emblematico">⭐ Emblemático</span>
                                {% else %}
                                <span class="tag tag-normal">Normal</span>
                                {% endif %}
                            </td>
                            <td>
                                {% if atr.tiene_audio %}
                                <span class="audio-indicator">🔊 Generado</span>
                                {% else %}
                                <span style="color: #999; font-size: 12px;">Pendiente</span>
                                {% endif %}
                            </td>
                            <td class="actions-cell">
                                <button class="btn-small btn-info" onclick="editAttraction({{ atr.id }})" style="background:#F6E7D8;color:#7A4A1E;">Editar</button>
                                <button class="btn-small btn-danger" onclick="deleteAttraction({{ atr.id }})">Eliminar</button>
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB: ESTAMPAS -->
        <div id="tab-estampas" class="tab-content">
            <div class="stats">
                <div class="stat-card">
                    <h3>Total Estampas</h3>
                    <div class="number">{{ stamp_stats.total }}</div>
                </div>
                <div class="stat-card">
                    <h3>Reclamadas</h3>
                    <div class="number">{{ stamp_stats.reclamadas }}</div>
                </div>
                <div class="stat-card">
                    <h3>Usuarios Activos</h3>
                    <div class="number">{{ stamp_stats.usuarios_activos }}</div>
                </div>
                <div class="stat-card">
                    <h3>Logros Desbloqueados</h3>
                    <div class="number">{{ stamp_stats.logros }}</div>
                </div>
            </div>

            <div class="actions">
                <button class="btn btn-primary" onclick="openStampModal('create')">
                    <span>+</span> Nueva Estampa
                </button>
                <button class="btn btn-info" onclick="loadStamps()">
                    <span>↻</span> Actualizar
                </button>
            </div>

            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Ilustración</th>
                            <th>Nombre</th>
                            <th>Atractivo</th>
                            <th>Rareza</th>
                            <th>Puntos</th>
                            <th>Reclamada</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="stamps-table-body">
                        <tr>
                            <td colspan="8" style="text-align:center;color:#999;padding:40px;">
                                Cargando estampas...
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Modal Atractivo -->
    <div id="modal" class="modal">
        <div class="modal-content">
            <h2 id="modal-title">🌴 Nuevo Lugar</h2>
            <form id="attraction-form" onsubmit="saveAttraction(event)">
                <input type="hidden" id="edit-id" value="">
                
                <div class="form-group">
                    <label>Nombre *</label>
                    <input type="text" id="nombre" required placeholder="Ej: Cristo Rey">
                </div>
                
                <div class="form-group">
                    <label>Descripción Técnica *</label>
                    <textarea id="descripcion" required placeholder="Descripción formal del lugar..."></textarea>
                </div>
                
                <div class="form-group">
                    <label>Descripción Caleña (para audio TTS)</label>
                    <textarea id="descripcion_caleña" placeholder="Texto en tono caleño para el audio. Ej: ¡Oís, ve! Este es el Cristo Rey..."></textarea>
                </div>
                
                <div class="form-group">
                    <label>Dirección</label>
                    <input type="text" id="direccion" placeholder="Ej: Cerro de los Cristales">
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                    <div class="form-group">
                        <label>Latitud</label>
                        <input type="number" step="any" id="latitud" placeholder="3.4359">
                    </div>
                    <div class="form-group">
                        <label>Longitud</label>
                        <input type="number" step="any" id="longitud" placeholder="-76.5649">
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Categoría / Componente</label>
                    <input type="text" id="componente" placeholder="Ej: Monumento, Arquitectura religiosa">
                </div>
                
                <div class="checkbox-group">
                    <input type="checkbox" id="es_emblematico">
                    <label for="es_emblematico" style="margin: 0;">Es emblemático (reconocible por cámara)</label>
                </div>
                
                <div class="form-group" style="margin-top: 16px;">
                    <label>Imagen</label>
                    <input type="file" id="imagen" accept="image/*">
                </div>
                
                <div style="display: flex; gap: 10px; margin-top: 20px;">
                    <button type="submit" class="btn btn-success">💾 Guardar</button>
                    <button type="button" class="btn" style="background: #F6E7D8; color: #7A4A1E;" onclick="closeModal()">Cancelar</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal Estampa -->
    <div id="stamp-modal" class="modal">
        <div class="modal-content">
            <h2 id="stamp-modal-title">🎴 Nueva Estampa</h2>
            <form id="stamp-form" onsubmit="saveStamp(event)">
                <input type="hidden" id="stamp-edit-id" value="">
                
                <div class="form-group">
                    <label>Nombre *</label>
                    <input type="text" id="stamp-nombre" required placeholder="Ej: Cristo Rey - El Guardián">
                </div>
                
                <div class="form-group">
                    <label>Descripción</label>
                    <textarea id="stamp-descripcion" placeholder="Datos curiosos sobre el monumento..."></textarea>
                </div>
                
                <div class="form-group">
                    <label>Atractivo Asociado</label>
                    <select id="stamp-atractivo">
                        <option value="">-- Sin atractivo --</option>
                        {% for atr in atractivos_emblematicos %}
                        <option value="{{ atr.id }}">{{ atr.nombre }}</option>
                        {% endfor %}
                    </select>
                </div>
                
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                    <div class="form-group">
                        <label>Rareza</label>
                        <select id="stamp-rareza">
                            <option value="comun">Común</option>
                            <option value="rara">Rara</option>
                            <option value="epica">Épica</option>
                            <option value="legendaria">Legendaria</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Puntos</label>
                        <input type="number" id="stamp-puntos" value="10" min="5" max="500">
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Categoría</label>
                    <select id="stamp-categoria">
                        <option value="monumento">Monumento</option>
                        <option value="gastronomia">Gastronomía</option>
                        <option value="naturaleza">Naturaleza</option>
                        <option value="evento">Evento</option>
                        <option value="cultura">Cultura</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Ilustración</label>
                    <input type="file" id="stamp-imagen" accept="image/*">
                    <small style="color: #7A4A1E;">Formato recomendado: 400x500px, PNG con transparencia</small>
                </div>
                
                <div style="display: flex; gap: 10px; margin-top: 20px;">
                    <button type="submit" class="btn btn-success">💾 Guardar</button>
                    <button type="button" class="btn" style="background: #F6E7D8; color: #7A4A1E;" onclick="closeStampModal()">Cancelar</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        const API_URL = '';
        
        // ===== TABS =====
        function switchTab(tabName) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
            
            event.target.classList.add('active');
            document.getElementById('tab-' + tabName).classList.add('active');
            
            if (tabName === 'estampas') loadStamps();
        }
        
        // ===== ATRACTIVOS =====
        function openModal(mode, id = null) {
            document.getElementById('modal').classList.add('active');
            document.getElementById('modal-title').textContent = mode === 'create' ? '🌴 Nuevo Lugar' : '✏️ Editar Lugar';
            document.getElementById('edit-id').value = id || '';
            if (mode === 'create') document.getElementById('attraction-form').reset();
        }
        
        function closeModal() {
            document.getElementById('modal').classList.remove('active');
        }
        
        async function saveAttraction(e) {
            e.preventDefault();
            const id = document.getElementById('edit-id').value;
            const data = {
                nombre: document.getElementById('nombre').value,
                descripcion: document.getElementById('descripcion').value,
                descripcion_caleña: document.getElementById('descripcion_caleña').value,
                direccion: document.getElementById('direccion').value,
                latitud: parseFloat(document.getElementById('latitud').value) || null,
                longitud: parseFloat(document.getElementById('longitud').value) || null,
                componente: document.getElementById('componente').value,
                es_emblematico: document.getElementById('es_emblematico').checked ? 1 : 0,
                intereses: []
            };
            
            try {
                let response;
                let resultId = id;
                if (id) {
                    response = await fetch(`${API_URL}/api/attractions/${id}`, {
                        method: 'PUT', headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data)
                    });
                } else {
                    response = await fetch(`${API_URL}/api/attractions`, {
                        method: 'POST', headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data)
                    });
                    const result = await response.json();
                    resultId = result.id;
                }
                if (resultId && document.getElementById('imagen').files[0]) {
                    const formData = new FormData();
                    formData.append('image', document.getElementById('imagen').files[0]);
                    await fetch(`${API_URL}/api/attractions/${resultId}/image`, {
                        method: 'POST', body: formData
                    });
                }
                location.reload();
            } catch (err) { alert('Error: ' + err.message); }
        }
        
        async function deleteAttraction(id) {
            if (!confirm('¿Eliminar este lugar permanentemente?')) return;
            try {
                await fetch(`${API_URL}/api/attractions/${id}`, { method: 'DELETE' });
                location.reload();
            } catch (err) { alert('Error: ' + err.message); }
        }
        
        async function editAttraction(id) {
            try {
                const response = await fetch(`${API_URL}/api/attractions/${id}`);
                const result = await response.json();
                if (result.success) {
                    const atr = result.data;
                    document.getElementById('nombre').value = atr.nombre || '';
                    document.getElementById('descripcion').value = atr.descripcion || '';
                    document.getElementById('descripcion_caleña').value = atr.descripcion_caleña || '';
                    document.getElementById('direccion').value = atr.direccion || '';
                    document.getElementById('latitud').value = atr.latitud || '';
                    document.getElementById('longitud').value = atr.longitud || '';
                    document.getElementById('componente').value = atr.componente || '';
                    document.getElementById('es_emblematico').checked = atr.es_emblematico === 1;
                    openModal('edit', id);
                }
            } catch (err) { alert('Error: ' + err.message); }
        }
        
        // ===== ESTAMPAS =====
        function openStampModal(mode, id = null) {
            document.getElementById('stamp-modal').classList.add('active');
            document.getElementById('stamp-modal-title').textContent = mode === 'create' ? '🎴 Nueva Estampa' : '✏️ Editar Estampa';
            document.getElementById('stamp-edit-id').value = id || '';
            if (mode === 'create') document.getElementById('stamp-form').reset();
        }
        
        function closeStampModal() {
            document.getElementById('stamp-modal').classList.remove('active');
        }
        
        async function loadStamps() {
            try {
                const response = await fetch(`${API_URL}/api/stamps`);
                const result = await response.json();
                const tbody = document.getElementById('stamps-table-body');
                
                if (!result.success || !result.data || result.data.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;color:#999;padding:40px;">No hay estampas en el catálogo</td></tr>';
                    return;
                }
                
                tbody.innerHTML = result.data.map(stamp => `
                    <tr>
                        <td>${stamp.id}</td>
                        <td>
                            ${stamp.imagen_url 
                                ? `<img src="${stamp.imagen_url}" class="stamp-preview" alt="${stamp.nombre}">`
                                : '<span style="color:#999;font-size:12px;">Sin ilustración</span>'
                            }
                        </td>
                        <td><strong>${stamp.nombre}</strong></td>
                        <td>${stamp.atractivo_nombre || '-'}</td>
                        <td><span class="tag tag-${stamp.rareza}">${stamp.rareza}</span></td>
                        <td>${stamp.puntos} pts</td>
                        <td>${stamp.reclamada_count || 0} veces</td>
                        <td class="actions-cell">
                            <button class="btn-small btn-info" onclick="editStamp(${stamp.id})" style="background:#F6E7D8;color:#7A4A1E;">Editar</button>
                            <button class="btn-small btn-danger" onclick="deleteStamp(${stamp.id})">Eliminar</button>
                        </td>
                    </tr>
                `).join('');
            } catch (err) {
                console.error('Error cargando estampas:', err);
            }
        }
        
        async function saveStamp(e) {
            e.preventDefault();
            const id = document.getElementById('stamp-edit-id').value;
            const data = {
                nombre: document.getElementById('stamp-nombre').value,
                descripcion: document.getElementById('stamp-descripcion').value,
                atractivo_id: document.getElementById('stamp-atractivo').value || null,
                rareza: document.getElementById('stamp-rareza').value,
                puntos: parseInt(document.getElementById('stamp-puntos').value) || 10,
                categoria: document.getElementById('stamp-categoria').value,
            };
            
            try {
                let response;
                let resultId = id;
                if (id) {
                    response = await fetch(`${API_URL}/admin/stamps/${id}`, {
                        method: 'PUT', headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data)
                    });
                } else {
                    response = await fetch(`${API_URL}/admin/stamps`, {
                        method: 'POST', headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data)
                    });
                    const result = await response.json();
                    resultId = result.id;
                }
                
                // Subir ilustración
                if (resultId && document.getElementById('stamp-imagen').files[0]) {
                    const formData = new FormData();
                    formData.append('image', document.getElementById('stamp-imagen').files[0]);
                    await fetch(`${API_URL}/admin/stamps/${resultId}/image`, {
                        method: 'POST', body: formData
                    });
                }
                
                closeStampModal();
                loadStamps();
            } catch (err) { alert('Error: ' + err.message); }
        }
        
        async function deleteStamp(id) {
            if (!confirm('¿Eliminar esta estampa? Se perderán los datos de usuarios que la reclamaron.')) return;
            try {
                await fetch(`${API_URL}/admin/stamps/${id}`, { method: 'DELETE' });
                loadStamps();
            } catch (err) { alert('Error: ' + err.message); }
        }
        
        async function editStamp(id) {
            try {
                const response = await fetch(`${API_URL}/api/stamps/${id}`);
                const result = await response.json();
                if (result.success) {
                    const stamp = result.data;
                    document.getElementById('stamp-nombre').value = stamp.nombre || '';
                    document.getElementById('stamp-descripcion').value = stamp.descripcion || '';
                    document.getElementById('stamp-atractivo').value = stamp.atractivo_id || '';
                    document.getElementById('stamp-rareza').value = stamp.rareza || 'comun';
                    document.getElementById('stamp-puntos').value = stamp.puntos || 10;
                    document.getElementById('stamp-categoria').value = stamp.categoria || 'monumento';
                    openStampModal('edit', id);
                }
            } catch (err) { alert('Error: ' + err.message); }
        }
    </script>
</body>
</html>
'''
