#!/bin/bash
# ==============================================================================
# SRA-SyncVault v2.0 - Interfaz Interactiva (CLI App)
# Extracción de SRA, compresión GZ al vuelo y sincronización blindada
# ==============================================================================

clear
echo "====================================================="
echo "          SRA-SyncVault - Motor de Extracción        "
echo "====================================================="

BASE_DIR=$(pwd)

# ---------------------------------------------------------
# FASE 1: AUDITORÍA DE SISTEMA Y DEPENDENCIAS
# ---------------------------------------------------------
if ! command -v prefetch &> /dev/null || ! command -v fastq-dump &> /dev/null; then
    echo "[ERROR CRÍTICO] SRA Toolkit no detectado en el PATH."
    exit 1
fi

MIN_GB=60
MIN_KB=$((MIN_GB * 1024 * 1024))
FREE_KB=$(df -Pk "$BASE_DIR" | awk 'NR==2 {print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))

if [ "$FREE_KB" -lt "$MIN_KB" ]; then
    echo "[ERROR CRÍTICO] Espacio insuficiente. Requerido: $MIN_GB GB. Disponible: $FREE_GB GB."
    exit 1
fi
echo "[OK] Dependencias y almacenamiento ($FREE_GB GB libres) validados."
echo "-----------------------------------------------------"

# ---------------------------------------------------------
# FASE 2: ASISTENTE INTERACTIVO (USER INPUT)
# ---------------------------------------------------------
echo ""
echo "[?] PASO 1: Archivo de Secuencias"
echo "Escribe el nombre del archivo de texto con los IDs SRA (Ej. lista.txt)"
read -e -p "> " LISTA

if [ ! -f "$LISTA" ]; then
    echo "[ERROR] El archivo '$LISTA' no existe en este directorio. Abortando."
    exit 1
fi

echo ""
echo "[?] PASO 2: Directorio de Exportación Físico"
echo "Escribe la ruta donde se guardarán los archivos finales comprimidos."
echo "Si dejas en blanco, se usará: $BASE_DIR/exportacion_final"
read -e -p "> " USB_DEST

# Lógica de autocompletado y fallback
if [ -z "$USB_DEST" ]; then
    USB_DEST="$BASE_DIR/exportacion_final"
fi

# Expansión de ~ a ruta absoluta y validación
USB_DEST="${USB_DEST/#\~/$HOME}"
if [ ! -d "$USB_DEST" ]; then
    echo "[*] Creando directorio de destino: $USB_DEST"
    mkdir -p "$USB_DEST" || { echo "[ERROR] Sin permisos para crear ruta destino."; exit 1; }
fi

echo "====================================================="
echo " CONFIGURACIÓN ASEGURADA. INICIANDO OPERACIONES."
echo "====================================================="

# Configuración de Mesa de Trabajo
SRA_DIR="$BASE_DIR/sra"
FASTQ_DIR="$BASE_DIR/fastq"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$SRA_DIR" "$FASTQ_DIR" "$LOG_DIR"

# ---------------------------------------------------------
# FASE 3: MOTOR DE EXTRACCIÓN Y BLINDAJE
# ---------------------------------------------------------
while read -r SRA_ID || [[ -n "$SRA_ID" ]]; do
    [[ -z "$SRA_ID" ]] && continue

    echo ""
    echo "[>>>] Procesando: $SRA_ID | $(date)"
    
    # 3.1 DESCARGA CON TOLERANCIA A FALLOS DE RED
    MAX_INTENTOS=3
    INTENTO=1
    EXITO=0

    while [ $INTENTO -le $MAX_INTENTOS ]; do
        echo "  - [1/4] Descargando (Intento $INTENTO de $MAX_INTENTOS)..."
        prefetch "$SRA_ID" --max-size 100G --output-directory "$SRA_DIR" > "$LOG_DIR/${SRA_ID}_prefetch.log" 2>&1
        
        if [ $? -eq 0 ]; then
            EXITO=1
            break
        else
            if [ $INTENTO -lt $MAX_INTENTOS ]; then
                echo "  - [ALERTA] Fallo de red. Reintentando en 10 seg..."
                sleep 10
            fi
            ((INTENTO++))
        fi
    done

    if [ $EXITO -eq 0 ]; then
        echo "  - [ERROR] Descarga fallida tras 3 intentos. Omitiendo $SRA_ID."
        continue
    fi

    # 3.2 EXTRACCIÓN Y COMPRESIÓN
    echo "  - [2/4] Extrayendo y comprimiendo en GZ..."
    fastq-dump --split-files --gzip --outdir "$FASTQ_DIR" "$SRA_DIR/$SRA_ID" >> "$LOG_DIR/${SRA_ID}_fastq.log" 2>&1
    
    if [[ $? -ne 0 ]]; then
        echo "  - [ERROR] Fallo en compresión. Omitiendo."
        continue
    fi

    # 3.3 TRANSFERENCIA Y SELLADO FÍSICO
    echo "  - [3/4] Transfiriendo al destino: $USB_DEST"
    cp "$FASTQ_DIR/${SRA_ID}"_*.fastq.gz "$USB_DEST/"
    
    if [[ $? -ne 0 ]]; then
        echo "[ERROR CRÍTICO] I/O Error en transferencia. Abortando pipeline."
        exit 1
    fi
    sync

    # 3.4 PURGA Y TERMO-REGULACIÓN
    echo "  - [4/4] Verificando redundancia y purgando RAM/Disco..."
    if ls "$USB_DEST/${SRA_ID}"_*.fastq.gz 1> /dev/null 2>&1; then
        rm -f "$FASTQ_DIR/${SRA_ID}"_*.fastq.gz
        rm -rf "$SRA_DIR/$SRA_ID"
        echo "  - [OK] Archivos originales destruidos."
    else
        echo "[ERROR CRÍTICO] Falla de escritura fantasma en destino."
        exit 1
    fi

    echo "  - [*] Enfriamiento térmico activado (5 min)..."
    sleep 300

done < "$LISTA"

echo ""
echo "====================================================="
echo " OPERACIÓN SRA-SYNCVAULT FINALIZADA EXITOSAMENTE"
echo "====================================================="
