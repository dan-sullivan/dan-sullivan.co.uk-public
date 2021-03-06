module.exports = function(grunt) {
  var serveStatic = require("serve-static"); // used in livereload middleware for connect
    grunt.initConfig({
        infraSvg: grunt.file.read("src/images/dscouk-infra-css.svg"),
        emailIconSvg: grunt.file.read("src/images/iconmonstr-email.svg"),
        linkedinIconSvg: grunt.file.read("src/images/iconmonstr-linkedin.svg"),
        githubIconSvg: grunt.file.read("src/images/iconmonstr-github.svg"),
        dockerIconSvg: grunt.file.read("src/images/fontawesome-docker.svg"),
        lambdaThisSite: grunt.file.read("src/templates/lambda-thissite.tpl"),
        s3cfThisSite: grunt.file.read("src/templates/s3cf-thissite.tpl"),
        localThisSite: grunt.file.read("src/templates/local-thissite.tpl"),
				clean: ["dist/", ".tmp/"],
        sass: {
					dist: {
						options: {
							style: "expanded"
						},
						files: {
							"dist/css/skeleton.css": "src/scss/skeleton.scss",
							"dist/css/main.css": "src/scss/main.scss",
							"dist/css/infrasvg.css": "src/scss/dscouk-lambda.scss"
						}
					},
					lambda: {
						options: {
							style: "expanded"
						},
						files: {
							"dist/css/infrasvg.css": "src/scss/dscouk-lambda.scss"
						}
					},
					s3cf: {
						options: {
							style: "expanded"
						},
						files: {
							"dist/css/infrasvg.css": "src/scss/dscouk-s3cf.scss"
						}
					}
        },
				browserify: { // bundle javascript for use
					dist: {
						src: "src/js/index.js",
						dest: ".tmp/js/bundle.js"
					}
				},
				uglify: {    // minify bundled js
					dist: {
						src: ".tmp/js/bundle.js",
						dest: "dist/js/bundle.min.js"
					} 
				},
        template: {
          dist: {
            options: {
              data: {
                "title": "Dan Sullivan",
                "infrasvg": "<%= infraSvg %>",
                "thissite": "<%= localThisSite %>",
                "emailIconSvg": "<%= emailIconSvg %>",
                "linkedinIconSvg": "<%= linkedinIconSvg %>",
                "githubIconSvg": "<%= githubIconSvg %>",
                "dockerIconSvg": "<%= dockerIconSvg %>",
              }
            },
            files: {
              "dist/index.html": ['src/index.html']
            } 
          },
          lambda: {
            options: {
              data: {
                "title": "Dan Sullivan",
                "infrasvg": "<%= infraSvg %>",
                "thissite": "<%= lambdaThisSite %>",
                "emailIconSvg": "<%= emailIconSvg %>",
                "linkedinIconSvg": "<%= linkedinIconSvg %>",
                "githubIconSvg": "<%= githubIconSvg %>",
                "dockerIconSvg": "<%= dockerIconSvg %>",
              }
            },
            files: {
              "dist/index.html": ['src/index.html']
            } 
          },
          s3cf: {
            options: {
              data: {
                "title": "Dan Sullivan",
                "infrasvg": "<%= infraSvg %>",
                "thissite": "<%= s3cfThisSite %>",
                "emailIconSvg": "<%= emailIconSvg %>",
                "linkedinIconSvg": "<%= linkedinIconSvg %>",
                "githubIconSvg": "<%= githubIconSvg %>",
                "dockerIconSvg": "<%= dockerIconSvg %>",
              }
            },
            files: {
              "dist/index.html": ['src/index.html']
            } 
          }
        },
				htmlclean: { // clean html
					dist: {
						cwd: "dist/",
						expand: true,
						src: "*.html",
						dest: "dist/"
					}
				},
				copy: {			// copy images from source image folder
					dist:{
						files: [{
						expand: true,
						cwd: "src/images/",
						src: "**",
						dest: "dist/images",
						},
            {
						expand: true,
						cwd: "src/images/",
						src: "favicon.ico",
						dest: "dist/",
						}
            ]
					}
				},
        exec: {
            zip_lambda_dscouk: 'ZIPFILE=$(pwd)/terraform/zips/serve_dscouk.zip; zip -r $ZIPFILE ./dist; cd terraform/; zip $ZIPFILE serve_dscouk.py',
            invalidate_cf: 'cd terraform/core ; terraform init;  aws cloudfront create-invalidation --distribution-id $(terraform output cloudfront_id) --paths "/*"',
            upload_s3cf: {
              cmd: function(branch_arg) {
                if (branch_arg) {
                  if (branch_arg == "master"){ branch_arg = "s3" } else { branch_arg = branch_arg + "/" + branch_arg + "/s3" };
                  return 'aws s3 sync --region eu-west-2 ./dist/ s3://dan-sullivan.co.uk/' + branch_arg;
                }
							}
						},
        },
        watch: {
					options: {
						livereload: true,
					},
					styles: {
						files: ["src/scss/**/*.scss"], // which files to watch
						tasks: ["sass"],
						options: {
							nospawn: true
						}
					},
					html: {
						files: ["src/*.html"], // which files to watch
						tasks: ["template:dist", "htmlclean"]
					},
					local: {
						files: ["src/templates/local*.tpl"], // which files to watch
						tasks: ["template:dist", "htmlclean"]
					},
					lambda: {
						files: ["src/templates/lambda*.tpl"], // which files to watch
						tasks: ["template:lambda", "htmlclean"]
					},
					s3cf: {
						files: ["src/templates/s3cf*.tpl"], // which files to watch
						tasks: ["template:s3cf", "htmlclean"]
					},
					js: {
						files: ["src/js/index.js"], // which files to watch
						tasks: ["browserify", "uglify"]
					}
        },
				connect: {
					server: {
						options: {
							port: 9000,
							middleware: function (connect) {
								return [
									require("connect-livereload")(), // inject livereload code to avoid relying on browser extensions
                  serveStatic("./dist/") // middleware overrides Connect defaults so use serveStatic
								];
							}
						}
					}
				}
    });

	grunt.loadNpmTasks("grunt-contrib-clean");
	grunt.loadNpmTasks("grunt-contrib-copy");
	grunt.loadNpmTasks("grunt-contrib-sass");
	grunt.loadNpmTasks("grunt-contrib-watch");
	grunt.loadNpmTasks("grunt-sass");
	grunt.loadNpmTasks("grunt-contrib-connect");
	grunt.loadNpmTasks("grunt-htmlclean");
	grunt.loadNpmTasks("grunt-contrib-uglify");
	grunt.loadNpmTasks("grunt-browserify");
  grunt.loadNpmTasks("grunt-template");
  grunt.loadNpmTasks('grunt-notify');
  grunt.loadNpmTasks('grunt-exec');
	grunt.registerTask("default", ["clean", "browserify:dist", "uglify:dist", "sass:dist", "template:dist", "htmlclean:dist", "copy:dist"]);
	grunt.registerTask("lambda", ["clean", "browserify:dist", "uglify:dist", "sass:dist", "sass:lambda", "template:lambda", "htmlclean:dist", "copy:dist"]);
	grunt.registerTask("s3cf", ["clean", "browserify:dist", "uglify:dist", "sass:dist", "sass:s3cf", "template:s3cf", "htmlclean:dist", "copy:dist"]);
	grunt.registerTask("serve", ["connect:server", "watch"]);
};
