import tornado.ioloop
import tornado.web

class MainHandler(tornado.web.RequestHandler):

    def get(self):
        self.write("test gitlab_cicd api success")

    def post(self):
        self.write("test gitlab_cicd api success")


def make_app():
    return tornado.web.Application([
        (r"/test", MainHandler),
    ], debug=True)


if __name__ == "__main__":
    app = make_app()
    app.listen(8744)
    tornado.ioloop.IOLoop.current().start()
