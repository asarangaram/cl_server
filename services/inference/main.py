from services.inference.src import app

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("services.inference.src:app", host="127.0.0.1", port=8001, reload=True)

