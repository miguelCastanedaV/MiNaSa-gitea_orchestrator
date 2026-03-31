# Guía de Instalación y Configuración de Gitea

Esta guía te ayudará a configurar Gitea con Registry privado y CI/CD (Gitea Actions) para gestionar múltiples proyectos privados sin costo.

**Ubicación**: `~/Documentos/Programming/Packages/gitea-server/` - Servidor aislado para todos tus proyectos

## 📋 Requisitos Previos

- Docker y Docker Compose instalados
- Puertos disponibles: 3000, 222, 5000

---

## 🚀 Paso 1: Levantar Gitea

```bash
cd ~/Documentos/Programming/Packages/gitea-server
docker-compose up -d
```

Espera 30 segundos para que Gitea inicie completamente.

---

## 🔧 Paso 2: Configuración Inicial de Gitea

1. Abre tu navegador en: **http://localhost:3000**

2. En la pantalla de instalación inicial, configura:
   - **Database Type**: PostgreSQL (ya configurado automáticamente)
   - **Host**: `gitea-db:5432`
   - **User**: `gitea`
   - **Password**: `gitea`
   - **Database Name**: `gitea`

3. **Configuración General del Servidor**:
   - **Site Title**: `Gestiona SIG - Repositorios Privados`
   - **Repository Root Path**: `/data/git/repositories`
   - **Git LFS Root Path**: `/data/git/lfs`

4. **Configuración de Administrador**:
   - **Username**: (tu usuario admin)
   - **Password**: (tu contraseña segura)
   - **Email**: (tu email)

5. Haz clic en **"Install Gitea"**

---

## 🔑 Paso 3: Configurar Runner de Actions (CI/CD)

Después de instalar Gitea:

1. Inicia sesión con tu usuario admin
2. Ve a: **Site Administration** (icono de herramientas arriba a la derecha)
3. Ve a: **Actions** → **Runners**
4. Haz clic en **"Create new runner"**
5. Copia el **Registration Token** que aparece

6. Edita el archivo `docker-compose.gitea.yml` y pega el token:

```yaml
gitea-runner:
  environment:
    GITEA_RUNNER_REGISTRATION_TOKEN: "TU_TOKEN_AQUI"
```

7. Reinicia el runner:

```bash
docker-compose -f docker-compose.gitea.yml restart gitea-runner
```

8. Verifica que el runner esté activo en **Site Administration → Actions → Runners**

---

## 📦 Paso 4: Crear Repositorios

### Ejemplo: Repositorio gs-phva (Laravel/PHP)

1. En Gitea, haz clic en **"+"** → **"New Repository"**
2. Configura:
   - **Owner**: Tu usuario
   - **Repository Name**: `gs-phva`
   - **Visibility**: ✅ **Private**
   - **Initialize repository**: ❌ (lo clonarás desde otro origen)

3. Agrega Gitea como remote en tu proyecto existente:

```bash
cd /ruta/a/tu/proyecto/gs-phva

# Agrega Gitea como remote
git remote add gitea http://localhost:3000/TU_USUARIO/gs-phva.git

# Push inicial
git push gitea main
```

### Ejemplo: Repositorio gs-react (React)

1. Crea otro repositorio en Gitea:
   - **Repository Name**: `gs-react`
   - **Visibility**: ✅ **Private**

2. Sube tu proyecto React:

```bash
cd /ruta/a/tu/proyecto/react

# Si aún no es un repo git
git init

# Agrega Gitea como remote
git remote add origin http://localhost:3000/TU_USUARIO/gs-react.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

**Nota**: Puedes crear tantos repositorios privados como necesites. Gitea no tiene límites.

---

## 🐳 Paso 5: Configurar Docker Registry

El registry ya está corriendo en `localhost:5000`.

### Configurar Docker para usar registry local (inseguro)

Edita `/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["localhost:5000", "192.168.1.XXX:5000"]
}
```

Reinicia Docker:

```bash
sudo systemctl restart docker
```

### Test del registry:

```bash
# Pull una imagen de prueba
docker pull alpine:latest

# Tag para tu registry
docker tag alpine:latest localhost:5000/test/alpine:latest

# Push
docker push localhost:5000/test/alpine:latest

# Verifica
curl http://localhost:5000/v2/_catalog
```

Deberías ver: `{"repositories":["test/alpine"]}`

---

## 🔐 Paso 6: Configurar Secrets para CI/CD

Para que tus workflows puedan acceder a recursos privados:

1. En cada repositorio, ve a: **Settings** → **Secrets**
2. Agrega los siguientes secrets:

### Para gs-phva (Laravel):
- `COMPOSER_AUTH`: (contenido de tu `auth.json` de Composer)
- `REGISTRY_URL`: `localhost:5000`

### Para gs-react (React):
- `NPM_TOKEN`: (si usas registry privado de npm)
- `REGISTRY_URL`: `localhost:5000`

---

## 📊 Verificación Final

Verifica que todos los servicios estén corriendo:

```bash
cd ~/Documentos/Programming/Packages/gitea-server
docker-compose ps
```

Deberías ver:
- ✅ `gitea` - running
- ✅ `gitea-db` - running
- ✅ `gitea-runner` - running
- ✅ `gitea-registry` - running

---

## 🎯 Próximos Pasos

1. ✅ Gitea instalado y configurado
2. ✅ Registry privado funcionando
3. ✅ Actions/CI/CD habilitado
4. ⏳ Crear Dockerfiles con stage `production`
5. ⏳ Crear workflows de CI/CD (`.gitea/workflows/`)
6. ⏳ Crear `docker-compose.prod.yml`

---

## 🆘 Troubleshooting

### El runner no se conecta

```bash
# Ver logs del runner
docker logs gitea-runner

# Si falla, vuelve a generar el token en Gitea y actualiza docker-compose.gitea.yml
```

### No puedo hacer push al registry

```bash
# Verifica que el registry esté en insecure-registries
docker info | grep -A 5 "Insecure Registries"

# Reinicia Docker después de editar daemon.json
sudo systemctl restart docker
```

### Gitea no inicia

```bash
# Ver logs
docker logs gitea

# Verificar permisos
ls -la docker/gitea_data/
```

---

## 📝 Notas Importantes

- **Cambiar secrets**: Edita `GITEA__security__SECRET_KEY` y `GITEA__oauth2__JWT_SECRET` con valores únicos
- **Backups**: Los datos están en volúmenes Docker. Usa `docker volume backup` regularmente
- **Seguridad**: Este setup es para desarrollo local. Para producción con acceso remoto, configura TLS/SSL

---

## 🔗 URLs Importantes

- **Gitea Web UI**: http://localhost:3000
- **Gitea SSH**: `ssh://git@localhost:222`
- **Docker Registry**: http://localhost:5000
- **Registry API**: http://localhost:5000/v2/_catalog

---

**¿Dudas?** Revisa la documentación oficial:
- Gitea: https://docs.gitea.io
- Gitea Actions: https://docs.gitea.io/next/usage/actions/overview
- Docker Registry: https://docs.docker.com/registry/

