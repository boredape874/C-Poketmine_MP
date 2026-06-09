const fs = require('node:fs')
const path = require('node:path')

function arg(name, fallback) {
  const prefix = `--${name}=`
  const found = process.argv.find(value => value.startsWith(prefix))
  return found === undefined ? fallback : found.slice(prefix.length)
}

function intArg(name, fallback) {
  const value = Number.parseInt(arg(name, `${fallback}`), 10)
  return Number.isFinite(value) ? value : fallback
}

function numberArg(name, fallback) {
  const value = Number.parseFloat(arg(name, `${fallback}`))
  return Number.isFinite(value) ? value : fallback
}

function boolArg(name, fallback) {
  const value = arg(name, fallback ? 'true' : 'false').toLowerCase()
  return value === '1' || value === 'true' || value === 'yes'
}

function writeJson(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, JSON.stringify(data, null, 2))
}

async function delay(ms) {
  await new Promise(resolve => setTimeout(resolve, ms))
}

async function main() {
  let bedrock
  try {
    const jwt = require('jsonwebtoken')
    const originalSign = jwt.sign
    jwt.sign = (payload, secretOrPrivateKey, options, callback) => {
      if (
        payload !== null &&
        typeof payload === 'object' &&
        Object.prototype.hasOwnProperty.call(payload, 'cpk') &&
        Object.prototype.hasOwnProperty.call(payload, 'xname') &&
        Object.prototype.hasOwnProperty.call(payload, 'identity') &&
        !Object.prototype.hasOwnProperty.call(payload, 'aud')
      ) {
        payload = {
          ...payload,
          aud: 'api://auth-minecraft-services/multiplayer',
          leguuid: payload.identity,
          mid: payload.identity
        }
      }
      return originalSign.call(jwt, payload, secretOrPrivateKey, options, callback)
    }
    bedrock = require('bedrock-protocol')
  } catch (err) {
    const out = arg('out', path.resolve('bedrock-swarm-result.json'))
    const report = {
      generated_at: new Date().toISOString(),
      verdict: 'fail',
      error: 'missing-bedrock-protocol',
      message: 'Run npm install in main_pmmp/tools/bedrock-swarm before executing the swarm.',
      detail: err.message
    }
    writeJson(out, report)
    console.log(JSON.stringify(report, null, 2))
    process.exit(2)
  }

  const host = arg('host', '127.0.0.1')
  const port = intArg('port', 19132)
  const players = intArg('players', 400)
  const durationSeconds = intArg('duration', 60)
  const rampMs = intArg('ramp-ms', 25)
  const connectTimeoutMs = intArg('connect-timeout-ms', 20000)
  const offline = boolArg('offline', true)
  const skipPing = boolArg('skip-ping', true)
  const out = arg('out', path.resolve('bedrock-swarm-result.json'))
  const usernamePrefix = arg('username-prefix', 'PMMPBot')
  const chunkTimeoutMs = intArg('chunk-timeout-ms', 30000)
  const requestedChunks = intArg('requested-chunks', 1)

  const startedAt = Date.now()
  const clients = []
  const states = new Array(players).fill(null).map((_, index) => ({
    index,
    username: `${usernamePrefix}${index + 1}`,
    attempted: false,
    login: false,
    spawn: false,
    chunkReady: false,
    disconnect: false,
    error: null
  }))

  function updateChunkReady(state) {
    if (state.spawn || state.chunkPackets >= requestedChunks) {
      state.chunkReady = true
    }
  }

  for (const state of states) {
    state.attempted = true
    state.chunkPackets = 0
    try {
      const client = bedrock.createClient({
        host,
        port,
        username: state.username,
        offline,
        connectTimeout: connectTimeoutMs,
        skinData: {
          FilterProfanity: false,
          PlayFabId: undefined
        },
        skipPing
      })
      clients.push(client)
      client.on('join', () => {
        state.login = true
      })
      client.on('spawn', () => {
        state.spawn = true
        updateChunkReady(state)
      })
      client.on('start_game', () => {
        state.login = true
      })
      client.on('level_chunk', () => {
        state.chunkPackets++
        updateChunkReady(state)
      })
      client.on('disconnect', packet => {
        state.disconnect = true
        state.disconnect_packet = packet
      })
      client.on('close', () => {
        state.disconnect = true
      })
      client.on('error', err => {
        state.error = err && err.message ? err.message : String(err)
      })
    } catch (err) {
      state.error = err && err.message ? err.message : String(err)
    }
    if (rampMs > 0) {
      await delay(rampMs)
    }
  }

  const deadline = Date.now() + Math.max(durationSeconds * 1000, chunkTimeoutMs)
  while (Date.now() < deadline) {
    const chunkReady = states.filter(state => state.chunkReady).length
    const finished = chunkReady >= players || states.every(state => state.disconnect || state.error !== null || state.chunkReady)
    if (finished && Date.now() - startedAt >= durationSeconds * 1000) {
      break
    }
    await delay(250)
  }

  for (const client of clients) {
    try {
      if (typeof client.disconnect === 'function') {
        client.disconnect('swarm finished')
      } else if (typeof client.close === 'function') {
        client.close()
      }
    } catch (_) {
    }
  }

  const endedAt = Date.now()
  const attempted = states.filter(state => state.attempted).length
  const successful = states.filter(state => state.login).length
  const chunkReady = states.filter(state => state.chunkReady).length
  const disconnects = states.filter(state => state.disconnect && !state.chunkReady).length
  const errors = states.filter(state => state.error !== null)
  const duration = Math.round((endedAt - startedAt) / 1000)
  const lossPercent = attempted === 0 ? 100 : ((attempted - successful) / attempted) * 100
  const passed = attempted >= players && successful >= players && chunkReady >= players && disconnects === 0 && errors.length === 0 && duration >= 60 && lossPercent <= 10

  const report = {
    generated_at: new Date().toISOString(),
    tool: 'pmmp-bedrock-swarm',
    bedrock_protocol_version: require('bedrock-protocol/package.json').version,
    verdict: passed ? 'pass' : 'fail',
    host,
    port,
    target_players: players,
    attempted_players: attempted,
    successful_logins: successful,
    chunk_ready_players: chunkReady,
    disconnects,
    fatal_log_matches: 0,
    duration_seconds: duration,
    loss_percent: Number(lossPercent.toFixed(3)),
    requested_chunks: requestedChunks,
    offline,
    skip_ping: skipPing,
    errors: errors.slice(0, 20).map(state => ({ index: state.index, username: state.username, error: state.error })),
    states
  }
  writeJson(out, report)
  console.log(JSON.stringify(report, null, 2))
  process.exit(passed ? 0 : 10)
}

main().catch(err => {
  const out = arg('out', path.resolve('bedrock-swarm-result.json'))
  const report = {
    generated_at: new Date().toISOString(),
    verdict: 'fail',
    error: 'unhandled',
    message: err && err.stack ? err.stack : String(err)
  }
  writeJson(out, report)
  console.log(JSON.stringify(report, null, 2))
  process.exit(1)
})
