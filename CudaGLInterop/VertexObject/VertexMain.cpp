// vertexMain.cpp adapted from Rob Farber's code from drdobbs.com

#include <GL/glew.h>
#include <GL/freeglut.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <helper_cuda.h>
#include <helper_cuda_gl.h>
#include <helper_timer.h>

// The user must create the following routines:
// CUDA methods
extern void initCuda(int argc, char** argv);
extern void runCuda();
extern void renderCuda(int);

// callbacks
extern void display();
extern void reshape(int, int);
extern void keyPressed(unsigned char, int, int);
extern void keyReleased(unsigned char, int, int);
extern void mouse(int, int, int, int);
extern void motion(int, int);
extern void timerEvent(int);
extern void idle();

// Timer for FPS calculations
StopWatchInterface* timer = NULL;

// Simple method to display the Frames Per Second in the window title
void computeFPS(){
	static int fpsCount=0;
	static int fpsLimit=60;
	if(++fpsCount==fpsLimit){
		float ifps=1000.f/sdkGetAverageTimerValue(&timer);	
		char fps[256];
		sprintf_s(fps, "Cuda GL Interop Wrapper: %3.1f fps ", ifps);
		glutSetWindowTitle(fps);
		fpsCount=0;
		fpsLimit=ifps>1.f? (int)ifps: 1;
		sdkResetTimer(&timer);
	}
}

void fpsDisplay(){
	sdkStartTimer(&timer);
	display();
	sdkStopTimer(&timer);
	computeFPS();
}

bool initGL(int* argc, char** argv){
	// create a window and GL context (also register callbacks)
	glutInit(argc, argv);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	glutInitWindowSize(720, 720);
	glutInitWindowPosition(0, 0);
	glutCreateWindow("Cuda GL Interop Wrapper (adapted from NVIDIA's simpleGL)");
	
	// register callbacks
	glutDisplayFunc(fpsDisplay);
	glutReshapeFunc(reshape);
	glutKeyboardFunc(keyPressed);
	glutKeyboardUpFunc(keyReleased);
	glutMouseFunc(mouse);
	glutMotionFunc(motion);
	glutTimerFunc(10, timerEvent, 0);
	glutIdleFunc(idle);

	// initialize necessary OpenGL extensions
	glewInit();
	if(!glewIsSupported("GL_VERSION_2_0 ")){
		fprintf(stderr, "ERROR: Support for necessary OpenGL extensions missing.");
		fflush(stderr);
		return false;
	}
	
	// default initialization
	glClearColor(0.f, 0.f, 0.f, 1.f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LESS);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glShadeModel(GL_SMOOTH);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

	glDisable(GL_CULL_FACE);
	//glCullFace(GL_BACK);

	SDK_CHECK_ERROR_GL();

	return true;
}

// Main program
int main(int argc, char** argv){
	sdkCreateTimer(&timer);

	if(!initGL(&argc, argv)){
		exit(EXIT_FAILURE);
	}

	initCuda(argc, argv);
	SDK_CHECK_ERROR_GL();

	// start rendering mainloop
	glutMainLoop();

	// clean up
	sdkDeleteTimer(&timer);
	cudaThreadExit();
	exit(EXIT_SUCCESS);
}