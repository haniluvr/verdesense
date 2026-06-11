const API_KEY = "AIzaSyAtxJApHXwlOyrcmnqA1P8TWbzWxtt7TLY";
const DB_URL = "https://verdesense-default-rtdb.asia-southeast1.firebasedatabase.app";

async function main() {
  const authRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: "hardware@verdesense.com",
      password: "temp1234",
      returnSecureToken: true
    })
  });
  
  const authData = await authRes.json();
  if (!authData.idToken) {
    console.error("Auth failed", authData);
    return;
  }
  const idToken = authData.idToken;

  const dbRes = await fetch(`${DB_URL}/.json?auth=${idToken}`);
  const dbData = await dbRes.json();
  
  console.log("DB Root Keys:", Object.keys(dbData || {}));
  console.log("Prototype Units:", JSON.stringify(dbData.prototype_units, null, 2));
  console.log("Sensor Data:", JSON.stringify(dbData.sensor_data, null, 2));
}

main().catch(console.error);
