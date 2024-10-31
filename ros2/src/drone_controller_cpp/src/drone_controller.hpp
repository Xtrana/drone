#pragma once
#include <cstdint>
#include <mavros_msgs/srv/command_bool.hpp>
#include <mavros_msgs/srv/detail/message_interval__struct.hpp>
#include <mavros_msgs/srv/message_interval.hpp>
#include <mavros_msgs/srv/set_mode.hpp>
#include <rclcpp/client.hpp>
#include <rclcpp/node.hpp>
#include <rclcpp/rclcpp.hpp>

#include "mavros_msgs/srv/detail/command_bool__struct.hpp"
#include "mavros_msgs/srv/detail/set_mode__struct.hpp"

class DroneControllerNode : public rclcpp::Node
{
private:
  rclcpp::Client<mavros_msgs::srv::SetMode>::SharedPtr mode_client_;
  rclcpp::Client<mavros_msgs::srv::MessageInterval>::SharedPtr stream_rate_client_;
  rclcpp::Client<mavros_msgs::srv::CommandBool>::SharedPtr arm_client_;

  rclcpp::TimerBase::SharedPtr service_timer_;
  void ServiceTimerCallback() const;

public:
  DroneControllerNode();

  void SetMode(const std::string & mode) const;
  void SetMessageInterval(uint32_t mavlink_message_id, float message_rate) const;
  void Arm() const;
  void ArmCallback(rclcpp::Client<mavros_msgs::srv::CommandBool>::SharedFuture future) const;
  void SetModeCallback(
    const rclcpp::Client<mavros_msgs::srv::SetMode>::SharedFuture & future) const;
  void MessageIntervalCallback(
    const rclcpp::Client<mavros_msgs::srv::MessageInterval>::SharedFuture & future) const;
};