from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pyodbc
from typing import List

app = FastAPI(
    title="PIXEurope Gateway API",
    description="Backend orchestration for the European Photonics Pilot Line (ICFO Prototype)",
    version="1.0.0"
)

# --- DATABASE CONNECTION ---
# Updated to localhost for your local SQL Server instance
def get_db_connection():
    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        "Server=localhost;" 
        "Database=PIXEurope;"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )
    try:
        return pyodbc.connect(conn_str)
    except pyodbc.Error as e:
        error_msg = f"Database connection failed: {e}"
        print(error_msg)
        if "ODBC" in str(e) or "Driver" in str(e):
            error_msg += "\n⚠️  ODBC Driver Issue (macOS users may need to install msodbcsql driver)"
        raise HTTPException(status_code=500, detail=error_msg)

# --- DATA MODELS (Pydantic) ---
class ServiceRequestCreate(BaseModel):
    company_id: int
    service_id: int
    partner_id: int
    request_title: str

class EquipmentStatus(BaseModel):
    AssetTag: str
    EquipmentName: str
    Status: str
    PartnerName: str

# --- ENDPOINTS ---

@app.get("/", tags=["Health"])
def read_root():
    return {
        "status": "Online",
        "system": "PIXEurope Data Gateway",
        "node": "Localhost Development"
    }

@app.get("/dashboard/kpis", tags=["Executive"])
def get_executive_kpis():
    """
    Fetches real-time KPIs for Prof. Valerio Pruneri.
    Aggregates data from the BI schema views.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM BI.vw_ExecutiveKPIs")
        columns = [column[0] for column in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        return results
    finally:
        conn.close()

@app.post("/gateway/apply", tags=["SME Access"])
def create_service_request(request: ServiceRequestCreate):
    """
    Coordinates an external SME application.
    Checks Partner status in 'Core' before writing to 'Gateway'.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Validation: Is the partner institution active?
        cursor.execute("SELECT IsActive FROM Core.Partners WHERE PartnerID = ?", request.partner_id)
        partner = cursor.fetchone()
        
        if not partner or not partner[0]:
            raise HTTPException(status_code=403, detail="The selected Partner Institution is currently not accepting new SME requests.")

        # Insert Request with auto-generated Request Number
        cursor.execute("""
            INSERT INTO Gateway.ServiceRequests (RequestNumber, CompanyID, ServiceID, AssignedPartnerID, RequestTitle)
            VALUES (?, ?, ?, ?, ?)
        """, (f"SR-{request.company_id}-2026", request.company_id, request.service_id, request.partner_id, request.request_title))
        
        conn.commit()
        return {"status": "Success", "message": "Application successfully routed to Partner review board."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@app.get("/compliance/audit-trail", tags=["Compliance"])
def get_audit_logs(limit: int = 10):
    """
    Demonstrates Audit Readiness for Chips JU.
    Fetches the latest security logs from the Compliance schema.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT TOP (?) * FROM Compliance.AuditLog ORDER BY EventTimestamp DESC", limit)
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
    finally:
        conn.close()

@app.get("/inventory/status", response_model=List[EquipmentStatus], tags=["Inventory"])
def get_global_inventory():
    """
    Returns high-level equipment status across the entire consortium.
    Essential for the 'Interoperability' milestone.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT e.AssetTag, e.EquipmentName, e.Status, p.PartnerName
            FROM Core.Equipment e
            JOIN Core.Partners p ON e.PartnerID = p.PartnerID
        """
        cursor.execute(query)
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
    finally:
        conn.close()


# --- APPLICATION ENTRY POINT ---
if __name__ == "__main__":
    import uvicorn
    print("Starting PIXEurope Gateway API on http://localhost:8000")
    print("API Documentation: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")