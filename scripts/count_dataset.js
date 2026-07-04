const fs = require('fs');
const path = require('path');
const data = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'sahte_oyuncular_ve_takimlar.json'), 'utf8'));
console.log('teams', data.teams.length, 'players', data.players.length);