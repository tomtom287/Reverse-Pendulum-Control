 # Reverse-Pendulum-Control

# Description of Problem
Our Project is the implementation of the reverse pendulum problem on an FPGA and VGA display. This problem in 2D involves a horizontal line attempting to "balance" a vertical line. A similar example is if you attmepted to balance a rod perfectly vertical on your hand. Due to gravity the pendulum wants to fall, but the movement of the horizontal line (with some mass) alters the motion of the pendulum. 

# Background Information 

Here are the mathematical models that define the dynamics of the system. These equations can be formulated into equations representing only angular acceleration and linear acceleration. Initially, all the variables (angular and linear acceleration, velocity, position) start at zero except for the position of the angle. 
[CamScanner 12-11-2024 22.43 2.pdf](https://github.com/user-attachments/files/18105222/CamScanner.12-11-2024.22.43.2.pdf)

# Description of Design 
The design uses a Finite State Machine to go through the calculations of finding new values of position, velocity, and acceleration. The Finite State Machine will also check each state to see if they are 0.

The VGA module takes both outputs (angle of the pendulum and linear position of pendulum) from the pendulum_problem and displaces each pixel from the original pendulum accoridngly. For example, if the output of the linear position from pendulum_problem was 2, the display would move 2 bits to the right. If the output of the angular position was .17 (10 degrees in radians) then the display will move the top pixel (pixel 150 on the screen with a height of 200) 200*.17 = 34 pixels to the right, and so forth for the entire length of the pendulum. 

To demo this design, first set the degree displacement by turning on switches SW[0] to SW[4] which will represent a clockwise dispalcment from the vertically upright pendulum. Press KEY[1] to load the displacement, then press and hold KEY[3] while pressing KEY[1] again. When KEY[3] is released, the pendulum will begin moving counterclockwise to stabilize, howveer currently it is only capable of one iteration.

# Video Demo 

# Conclusion 
This FPGA-based reverse pendulum simlulation models the dyanmics of a reverse pendulum for one iteration. Real-time performance could be achieved by refining the states and KEY declarations in the modules. 

# Works Cited 
his VGA memory_2 module for sure, other then that idk 


