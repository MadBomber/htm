# Module HTM::LongTermMemory::RobotOperations <a id="module-HTM-LongTermMemory-RobotOperations"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/robot_operations.rb |

Robot registration and activity tracking

Handles robot lifecycle management including:
*   Registration (find or create)
*   Activity timestamp updates

## Public Instance Methods
### `register_robot(robot_name)` <a id="method-i-register_robot"></a> <a id="register_robot-instance_method"></a>
Register a robot
- **`@param`** `robot_name` [String] Robot name
- **`@return`** [Integer] Robot ID

### `update_robot_activity(robot_id)` <a id="method-i-update_robot_activity"></a> <a id="update_robot_activity-instance_method"></a>
Update robot activity timestamp
- **`@param`** `robot_id` [Integer] Robot identifier
- **`@return`** [void]
