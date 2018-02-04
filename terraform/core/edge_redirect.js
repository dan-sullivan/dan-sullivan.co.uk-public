'use strict';

exports.handler = (event, context, callback) => {
    /*
     * Generate a random HTTP redirect response with 307 status code and Location header.
     */
    const redirects = [
      '/lambda/index.html',
      '/s3/index.html'
    ];

    const redirect_url = redirects[Math.floor(Math.random() * redirects.length)]; 
    const response = {
        status: '307',
        statusDescription: 'Temporary Redirect',
        headers: {
            location: [{
                key: 'Location',
                value: 'https://dan-sullivan.co.uk' + redirect_url,
            }],
        },
    };
    callback(null, response);
};

