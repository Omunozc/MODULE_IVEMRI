Perfecto 👌 aquí tienes la guía redactada en **tercera persona**, lista para colocar en el `README.md` del repositorio.

---

# 📘 Guía de Trabajo – GitFlow

Este proyecto utiliza una estructura basada en **GitFlow** para mantener orden en el desarrollo, facilitar el trabajo colaborativo y garantizar estabilidad en producción.

---

## 🔷 1. Estructura de ramas

### Ramas principales

* **main**
  Contiene el código en producción.

* **develop**
  Rama de integración donde se consolidan los desarrollos antes de pasar a producción.

---

### Ramas temporales

* **feature/** → Nuevas funcionalidades.
* **bugfix/** → Correcciones realizadas sobre `develop`.
* **hotfix/** → Correcciones urgentes en producción (parten de `main`).
* **release/** → Preparación de versiones antes de liberar a producción.

---

## 🔷 2. Convención de nombres

Se establece la siguiente estructura para nombrar ramas:

```
tipo/usuario-descripcion-corta
```

### Prefijos de usuario

* `tm` → Tomás
* `os` → Óscar

---

### Ejemplos

#### Nueva funcionalidad

```
feature/tm-login-vehiculos
feature/os-reporte-matriz-riesgo
```

#### Corrección sobre develop

```
bugfix/tm-error-calculo-saldo
bugfix/os-filtro-fechas
```

#### Corrección urgente en producción

```
hotfix/tm-fix-token-expirado
```

#### Preparación de versión

```
release/v1.2.0
```

---

## 🔷 3. Flujo de trabajo

### 1️⃣ Actualizar rama base

Antes de iniciar cualquier desarrollo:

```bash
git checkout develop
git pull origin develop
```

---

### 2️⃣ Crear nueva rama

```bash
git checkout -b feature/tm-modulo-stod
```

---

### 3️⃣ Realizar commits

Se recomienda utilizar el siguiente estándar:

* `feat:` nueva funcionalidad
* `fix:` corrección
* `refactor:` mejora interna
* `docs:` documentación

Ejemplo:

```bash
git commit -m "feat: se agrega módulo STOD"
```

---

### 4️⃣ Subir la rama

```bash
git push origin feature/tm-modulo-stod
```


---

## 🔷 4. Reglas generales

* No trabajar directamente sobre `main`.
* No trabajar directamente sobre `develop`.
* Cada funcionalidad debe desarrollarse en su propia rama.
* Las ramas deben tener nombres claros y descriptivos.
* Antes de crear una rama nueva, siempre actualizar `develop`.

---

## 🔷 5. Flujo general

```
main
  ↑
release
  ↑
develop
  ↑
feature/tm-xxx
feature/os-xxx
```

---

## 🔷 6. Buenas prácticas adicionales

En caso de utilizar sistema de tickets, se recomienda incluir el número correspondiente en el nombre de la rama:

```
feature/tm-123-modulo-stod
bugfix/os-145-error-token
```
