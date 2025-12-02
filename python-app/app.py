import os
import logging
from flask import Flask, jsonify, request
import requests
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

# Configuração do OpenTelemetry
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "python-app")
})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
    insecure=True
)

span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# A propagação de contexto é feita automaticamente pelo RequestsInstrumentor
# Ele usa W3C Trace Context por padrão

# Configuração do Flask
app = Flask(__name__)

# Instrumentação automática
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Variáveis de ambiente
APP_NAME = os.getenv("APP_NAME", "python-app")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
TARGET_URL = os.getenv("TARGET_URL", "")

@app.route('/health', methods=['GET'])
def health():
    """Endpoint de health check"""
    return jsonify({
        "status": "healthy",
        "app": APP_NAME,
        "port": APP_PORT
    }), 200

@app.route('/api/start', methods=['GET'])
def start():
    """Endpoint que dispara requisição para o target_url"""
    if not TARGET_URL:
        return jsonify({
            "error": "TARGET_URL não configurado",
            "app": APP_NAME
        }), 400
    
    try:
        logger.info(f"{APP_NAME} enviando requisição para {TARGET_URL}")
        # Criar span para a requisição externa
        # O RequestsInstrumentor já propaga o contexto automaticamente
        with tracer.start_as_current_span("start_request") as span:
            span.set_attribute("http.method", "GET")
            span.set_attribute("http.url", TARGET_URL)
            span.set_attribute("app.name", APP_NAME)
            
            response = requests.get(TARGET_URL, timeout=5)
            
            span.set_attribute("http.status_code", response.status_code)
            
            return jsonify({
                "status": "success",
                "app": APP_NAME,
                "target": TARGET_URL,
                "response_status": response.status_code,
                "response_body": response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text
            }), 200
    except requests.exceptions.RequestException as e:
        logger.error(f"Erro ao fazer requisição: {str(e)}")
        return jsonify({
            "status": "error",
            "app": APP_NAME,
            "target": TARGET_URL,
            "error": str(e)
        }), 500

@app.route('/api/receive', methods=['GET', 'POST'])
def receive():
    """Endpoint que recebe requisições"""
    method = request.method
    data = request.get_json() if request.is_json else request.args.to_dict()
    
    logger.info(f"{APP_NAME} recebeu requisição {method} com dados: {data}")
    
    return jsonify({
        "status": "received",
        "app": APP_NAME,
        "method": method,
        "data": data,
        "message": f"Requisição recebida com sucesso em {APP_NAME}"
    }), 200

@app.route('/', methods=['GET'])
def root():
    """Endpoint raiz"""
    return jsonify({
        "app": APP_NAME,
        "port": APP_PORT,
        "endpoints": {
            "/health": "GET - Health check",
            "/api/start": "GET - Dispara requisição para TARGET_URL",
            "/api/receive": "GET/POST - Recebe requisições"
        }
    }), 200

if __name__ == '__main__':
    logger.info(f"Iniciando {APP_NAME} na porta {APP_PORT}")
    app.run(host='0.0.0.0', port=APP_PORT, debug=False)

