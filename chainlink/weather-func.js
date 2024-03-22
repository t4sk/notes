// Open weather example
const lat = args[6]
const lon = args[7]

const API_KEY = secrets.OPEN_WEATHER_API_KEY

if (!secrets.OPEN_WEATHER_API_KEY) {
  throw Error("OPEN_WEATHER_API_KEY not set")
}

const req = Functions.makeHttpRequest({
  url: `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`,
})

const res = await req

if (res.error) {
  console.error(res.error)
  throw Error("Request failed")
}

console.log("response", res.data)

const temp = res.data.main.temp

return Functions.encodeInt256(Math.round(temp * 100))
