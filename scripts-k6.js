import http from 'k6/http';
import { check } from 'k6';


export const options = {
    vus: 100,
    duration: '60s',
    // thresholds: {
    //     http_req_duration: ['max<500']
    // }
};

const headers = { 'Content-Type': 'application/json',
                  'Authorization': 'Bearer' };

export default function () {
    const payload = JSON.stringify(
        {
            "session_id": null,
            "question": "Bagaimana mekanisme pengadaan sparepart di atas 2 miliar rupiah ?",
            "scope": {
                "document_scope": null,
                "document_type": null,
                "document_level": null,
                "area": null,
                "acReg": null
              }
        }
    );
    
    const res = http.post('https://api-prod.gmf-aeroasia.co.id/td/heroai/chat/messages', payload, { headers });
    check(res, { 
        'status was 200': (r) => r.status == 200,
        'response name same with payload': (r) => JSON.parse(r.body)['name'] == JSON.parse(payload)['name']
    });
}