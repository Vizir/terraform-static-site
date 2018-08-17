'use strict';

module.exports.handler = async function (event, context) {
  const request = event.Records[0].cf.request;

  if (request.uri === '/manifest.json') {
    return request;
  }

  const { headers } = request;
  const user = '${user}';
  const password = '${password}';

  const authString = 'Basic ' + new Buffer(user + ':' + password).toString('base64');

  if (typeof headers.authorization === 'undefined' || headers.authorization[0].value !== authString) {
    return {
      status: '401',
      statusDescription: 'Unauthorized',
      body: 'Unauthorized',
      headers: {
        'www-authenticate': [{ key: 'WWW-Authenticate', value: 'Basic' }]
      }
    };
  }

  return request;
};
