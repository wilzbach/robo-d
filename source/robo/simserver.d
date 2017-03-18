module robo.simserver;

import robo.iserver : IRoboServer;

import vibe.core.log;
import vibe.data.json;

import std.math;
import std.typecons : Nullable;

int MAX_DIST = 5000;
int MIN_DIST = 0;
int MAX_ANGLE = 360;
int MIN_ANGLE = 0;

auto radians(V)(V v)
{
    return sin(v * (PI / 180));
}

class HackBackSimulator : IRoboServer
{
    // round x/y position
    int ROUND_DIGITS = 0;
    // The radius of the robot in cm
    int RADIUS_CM = 7;
    // factor robot distance (tacho counts) to cm (20 tacho counts ca. 1 cm)
    int TACHO_COUNT_CM_FACTOR = 20;
    // factor between robot distance and x/y positional system
    double POSITION_FACTOR = 3.328125;

    string robot_channel = "robot/state";

    // state variables
    double x, y, r, angle;
    double startX, startY, startR, startAngle;
    double leftDistance = 0, rightDistance = 0;

    this(double x=0, double y=0, double r=15, double angle=0) {
        this.x = this.startX = x;
        this.y = this.startX = y;
        this.r = this.startR = r;
        this.angle = this.startAngle = angle;
        import std.stdio;
        writeln(this.angle);
    }

    /**
    Move the robot forward by a given distance.
    Params:
        distance = the distance the robot should move forward.
    */
    void forward(int distance)
    {
        auto movedX = cos(radians(angle)) * distance / POSITION_FACTOR;
        auto movedY = sin(radians(angle)) * distance / POSITION_FACTOR;
        x += movedX;
        y += movedY;
        leftDistance += distance;
        rightDistance += distance;
    }

    /**
    Move the robot backward by a given distance.
    Params:
        distance = the distance the robot should move forward.
    */
    void backward(int distance)
    {
        auto movedX = cos(radians(angle)) * distance / POSITION_FACTOR;
        auto movedY = sin(radians(angle)) * distance / POSITION_FACTOR;
        x -= movedX;
        y -= movedY;
        leftDistance -= distance;
        rightDistance -= distance;
    }

    /**
    Turn the robot right by a given angle (degrees).
    Params:
        angle = the angle in degrees.
    */
    void right(int _angle)
    {
        angle -= _angle;
        auto distance = calc_distance_with_angle(_angle);
        rightDistance -= distance;
        leftDistance += distance;
    }

    /**
    Turn the robot left by a given angle (degrees).
    Params:
        angle = the angle in degrees.
    */
    void left(int _angle)
    {
        angle += _angle;
        auto distance = calc_distance_with_angle(_angle);
        rightDistance += distance;
        leftDistance -= distance;
    }


    /**
    Sets the robot back to the staring position.
    */
    void reset()
    {
        x = startX;
        y = startY;
        angle = startAngle;
        rightDistance = 0;
        leftDistance = 0;
    }

    /**
    The current position and radius (x,y,r) from the robot.
    Returns: the x, y coordinates and radius as tuple
    */
    IRoboServer.RoboPosition position() {
        IRoboServer.RoboPosition r = {
            x:x,
            y:y,
            r:r,
        };
        return r;
        //return int(round(self.__x, self.ROUND_DIGITS)), int(round(self.__y, self.ROUND_DIGITS)), self.__r
    }

    void position(IRoboServer.RoboPosition pos)
    {
        x = pos.x;
        y = pos.y;
        r = pos.r;
    }

    /// stops the robot
    void stop() {}

    /**
    Returns the state of the robot (distance right / left motor and angle)
    Returns: map {'right_motor', 'lef_motor', 'angle'} with the current values distance
    left motor, distance right motor and current angle in degrees of the robot.
    The real angle from gyro is the current angle multiplied with -1
    */
    IRoboServer.RoboState state()
    {
        IRoboServer.RoboState r = {
            rightMotor: rightDistance,
            leftMotor: leftDistance,
            angle: -angle,
        };
        return r;

    }

    /**
    Calculate the distance when the robot turns a given angle in degree.
    Params:
        angle = angle in degree
    Returns: distance in tacho counts
    */
    private auto calc_distance_with_angle(double angle)
    {
        return 2 * RADIUS_CM * PI * angle / 360 * TACHO_COUNT_CM_FACTOR;
    }

    override string toString()
    {
        import std.string : format;
        return format("x: %s, y: %s, angle: %s", x, y, angle);
    }
}

/**
Decorator for the Simulator, extends the Simulator with dimension time.
*/
class TimeDecorator : IRoboServer
{
    HackBackSimulator simulator;
    NextCommand nextCommand;
    int tachoPerTick;

    struct NextCommand
    {
        Nullable!string command;
        Nullable!int value;
    }

    this(HackBackSimulator simulator, int tachoPerTick = 20)
    {
        this.simulator = simulator;
        this.tachoPerTick = tachoPerTick;
        nextCommand = NextCommand();
    }

    void forward(int distance)
    {
        nextCommand.command = "forward";

        if (distance <= tachoPerTick)
        {
            simulator.forward(distance);
            nextCommand = NextCommand();
        }
        else
        {
            simulator.forward(tachoPerTick);
            nextCommand.value = distance - tachoPerTick;
        }
    }

    void backward(int distance)
    {
        nextCommand.command = "backward";

        if (distance <= tachoPerTick)
        {
            simulator.backward(distance);
            nextCommand = NextCommand();
        }
        else
        {
            simulator.backward(tachoPerTick);
            nextCommand.value = distance - tachoPerTick;
        }
    }

    void reset()
    {
        nextCommand = NextCommand();
        simulator.reset();
    }

    void stop()
    {
        nextCommand = NextCommand();
    }

    void left(int angle)
    {
        simulator.left(angle);
        nextCommand = NextCommand();
    }

    void right(int angle)
    {
        simulator.right(angle);
        nextCommand = NextCommand();
    }

    override string toString()
    {
        return simulator.toString;
    }

    void tick()
    {
        if (nextCommand.command.isNull)
            return;

        if (nextCommand.command == "forward")
        {
            forward(nextCommand.value.get);
        }
        else if (nextCommand.command == "backward")
        {
            backward(nextCommand.value.get);
        }
    }

    IRoboServer.RoboPosition position()
    {
        return simulator.position;
    }

    void position(IRoboServer.RoboPosition pos)
    {
        simulator.position(pos);
    }

    IRoboServer.RoboState state()
    {
        return simulator.state;
    }
}
