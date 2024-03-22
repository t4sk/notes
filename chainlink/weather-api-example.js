/*
1. Sign up to https://openweathermap.org/
2. Click API keys -> Get API key
3. Execute script
4. Check weather on google
*/
const API_KEY = "9100acc87e19f27955fe6a1bef472852"

async function main() {
  // London
  const lat = 51.509865
  const lon = -0.118092
  // current weather
  // https://openweathermap.org/current
  const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`
  const res = await fetch(url)
  const json = await res.json()
  console.log(json)
}

main()
