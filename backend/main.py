from fastapi import FastAPI

app = FastAPI(title="Lecture Agent API")

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Lecture Agent Server Running"}