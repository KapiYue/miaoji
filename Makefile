.PHONY: server-start server-test

server-start:
	cd server && venv/bin/python -m flask --app app run --host 0.0.0.0 --port 8000

server-test:
	server/venv/bin/python -m unittest server/test_app.py server/test_evaluate_omni.py
