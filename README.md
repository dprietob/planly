# Planly
Aplicación para el diseño de planos a escala.

## Estado
Work in progress.

## Compilación y desarrollo
Para compilar la aplicación es necesario tener instalado en el sistema **Java 25+** o superior y **Maven**. Una vez instalados, hay que ejecutar los siguientes pasos:

```shell
# Abre un terminal (PowerShell para Windows, Terminar para MacOS o Linux)

# Asegúrate que tienes Git instalado
# Visita https://git-scm.com para descargar e instalar la consola de Git si no la tienes ya instalada

# Clona el repositorio
git clone git@github.com:dprietob/planly.git

# Navega hasta el directorio raíz del proyecto
cd planly

# Verifica que tengas Java y Maven instalado
java --version
mvn --version

# Compila la aplicación
mvn clean package

# Ejecuta la aplicación
java -jar target/planly-1.0-SNAPSHOT.jar

# Para desarrollo + testeo, se puede ejecutar ambos comandos directamente
mvn clean package && java -jar target/planly-1.0-SNAPSHOT.jar
```
