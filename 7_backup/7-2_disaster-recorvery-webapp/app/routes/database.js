var express = require('express');
var router = express.Router();
var Connection = require('tedious').Connection;

/* GET users listing. */
router.get('/', function (req, res, next) {
  const readOnly = process.env.SQL_DATABASE_READONLY !== undefined && process.env.SQL_DATABASE_READONLY.toLowerCase() === 'true';
  const config = {
    server: process.env.SQL_DATABASE_SERVER,
    authentication: {
      type: 'default',
      options: {
        userName: process.env.SQL_DATABASE_USERNAME,
        password: process.env.SQL_DATABASE_PASSWORD,
      }
    },
    options: {
      encrypt: true,
      database: process.env.SQL_DATABASE_NAME,
      readOnlyIntent: readOnly,
    }
  }
  var connection = new Connection(config);
  connection.on('connect', function (err) {
    res
      .status(200)
      .append('Content-Type', 'application/json')
      .send({
        status: !err ? 'connected' : 'failed to connect',
        server: process.env.SQL_DATABASE_SERVER,
        error: err,
        readOnly: readOnly,
      });
  });
  connection.connect();
  connection.close();
});

module.exports = router;
