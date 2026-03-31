# Gitea Server - Servidor Git Privado Multi-Proyecto

Este directorio contiene tu servidor Gitea privado que puedes usar para **todos tus proyectos**.

## 🎯 Propósito

Servidor Git privado + Docker Registry + CI/CD para múltiples proyectos sin costos.

## 📂 Estructura

```
~/Documentos/Programming/Packages/gitea-server/
├── docker-compose.yml      # Stack completo de Gitea
├── start-gitea.sh          # Script de inicio rápido
├── SETUP.md                # Guía completa de instalación
├── .gitignore              # Ignorar datos locales
└── (datos en volúmenes Docker)
```

## 🚀 Inicio Rápido

```bash
cd ~/Documentos/Programming/Packages/gitea-server
./start-gitea.sh
```

O manualmente:

```bash
docker-compose up -d
```

## 🌐 Accesos

- **Gitea Web UI**: http://localhost:3000
- **Gitea SSH**: `ssh://git@localhost:222`
- **Docker Registry**: http://localhost:5000
- **Registry API**: http://localhost:5000/v2/_catalog

## 📦 Proyectos que pueden usar este servidor

- ✅ gs-phva (Laravel/PHP)
- ✅ gs-react (React)
- ✅ Cualquier otro proyecto que agregues

## 🔧 Gestión

### Ver estado
```bash
docker-compose ps
```

### Ver logs
```bash
docker-compose logs -f
```

### Detener
```bash
docker-compose down
```

### Detener y eliminar datos (⚠️ CUIDADO)
```bash
docker-compose down -v
```

## 📖 Documentación Completa

Lee `SETUP.md` para instrucciones detalladas de:
- Instalación inicial
- Configuración de runners (CI/CD)
- Creación de repositorios
- Configuración del registry
- Troubleshooting

## 🔐 Seguridad

**Importante**: Cambia estos secrets en `docker-compose.yml`:
- `GITEA__security__SECRET_KEY`
- `GITEA__oauth2__JWT_SECRET`

Genera valores únicos y largos (mínimo 64 caracteres).

## 💾 Backup

Los datos están en volúmenes Docker:
- `gitea_data` - Repositorios y configuración
- `gitea_db` - Base de datos PostgreSQL
- `registry_data` - Imágenes Docker
- `gitea_runner_data` - Datos del CI/CD runner

Para hacer backup:
```bash
docker volume ls | grep gitea
docker run --rm -v gitea_data:/data -v $(pwd):/backup alpine tar czf /backup/gitea-backup.tar.gz /data
```

## 🆘 Soporte

Si tienes problemas, revisa:
1. `SETUP.md` - Sección Troubleshooting
2. Logs: `docker-compose logs`
3. Documentación oficial: https://docs.gitea.io

---

**Creado**: 2026-03-05  
**Versión Gitea**: 1.22  
**Propósito**: Servidor privado multi-proyecto

