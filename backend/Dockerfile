# BUILD STAGE
FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY . .

RUN go mod tidy && CGO_ENABLED=0 GOOS=linux go build -o skillpulse .

# DISTROLESS STAGE
FROM gcr.io/distroless/static-debian12

WORKDIR /

COPY --from=builder /app/skillpulse /skillpulse

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/skillpulse"]
