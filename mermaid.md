flowchart LR
C[Users] -->|HTTPS| T[Traefik]

subgraph VPS
T

    subgraph Supabase (stack)
      PG[(Postgres 15/16)]
      AUTH[GoTrue/Auth]
      REST[PostgREST]
      RT[Realtime]
      ST[Storage]
      STD[Studio]
    end

    subgraph Cyberdyne
      CYB_WEB[React/Next:3000]
      CYB_API[NestJS:4000]
    end

    subgraph Dental-IO
      DIO_WEB[React/Next:3000]
      DIO_API[NestJS:4000]
    end
end

%% Rutas públicas
T -->|auth.*| AUTH
T -->|rest.*| REST
T -->|realtime.*| RT
T -->|storage.*| ST
T -->|studio.*| STD

%% Apps
T -->|www/staging/lab.cyberdyne| CYB_WEB
T -->|/api (cyberdyne)| CYB_API
T -->|www/staging/lab.dental-io| DIO_WEB
T -->|/api (dental-io)| DIO_API

%% Acceso interno
CYB_API --- PG
DIO_API --- PG
