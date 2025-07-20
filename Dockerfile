FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix tzdata

LABEL version="2.3.0" \
      description="Api to control whatsapp features through http requests." \
      maintainer="Davidson Gomes" \
      git="https://github.com/DavidsonGomes" \
      contact="contato@evolution-api.com"

WORKDIR /evolution

# install deps
COPY package.json tsconfig.json ./
RUN npm install

# copy source & scripts
COPY src ./src
COPY public ./public
COPY prisma ./prisma
COPY manager ./manager
COPY runWithProvider.js ./
COPY tsup.config.ts ./
COPY Docker/scripts ./Docker/scripts

RUN chmod +x Docker/scripts/* && dos2unix Docker/scripts/*

# optionally generate DB schema at build time
RUN ./Docker/scripts/generate_database.sh

# build TS
RUN npm run build

# final image
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo \
    NODE_ENV=production \
    DOCKER_ENV=true

WORKDIR /evolution

# copy only built artifacts & runtime files
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/Docker/scripts ./Docker/scripts

EXPOSE 8080

ENTRYPOINT ["bash","-c","./Docker/scripts/deploy_database.sh && npm run start:prod"]
