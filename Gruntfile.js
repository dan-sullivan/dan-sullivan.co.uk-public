module.exports = function(grunt) {
  var serveStatic = require("serve-static"); // used in livereload middleware for connect
    grunt.initConfig({
        infraSvg: grunt.file.read("src/images/dscouk-infra-css.svg"),
				clean: ["dist/", ".tmp/"],
        sass: {
					dist: {
						options: {
							style: "expanded"
						},
						files: {
							"dist/css/skeleton.css": "src/scss/skeleton.scss",
							"dist/css/main.css": "src/scss/main.scss"
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
						}]
					}
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
						tasks: ["template", "htmlclean"]
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
	grunt.registerTask("default", ["clean", "browserify", "uglify", "sass", "template", "htmlclean", "copy"]);
	grunt.registerTask("serve", ["connect:server", "watch"]);
};
