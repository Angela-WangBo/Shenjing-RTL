# Shenjing
-------------------------------------
## Download latest release

[Download](https://github.com/Angela-WangBo/Shenjing-RTL/releases/download/v1.0/Shenjing-RTL-1.0.zip)

## Paper

[https://arxiv.org/abs/1911.10741](https://arxiv.org/abs/1911.10741)

Shenjing is a low power, reconfigurable architecture for neuromorphic computing. Specifically, it is built for Spiking Neural Networks (SNNs) for energy efficient Artificial Intelligence on edge devices. By its unique networks-on-chip (NoCs), Shenjing can support seamless transfer learning, where popular Artificial Neural Networks such as MLP, CNN, ResNet and etc. can be converted to SNNs without incurring mapping loss.

This repo contains the RTL implementation of Shenjing. Shenjing.sv is the top design file.

![Framework](https://raw.githubusercontent.com/Angela-WangBo/Shenjing-RTL/master/framework.png)

As illustrated above, shenjing is composed of three critical components: (a) neuron core; (b) partial-sum NoCs and (c) spike NoCs. A neuron core generates 256 local partial sums. A partial-sum NoC either propogates the partial sum or add it with an incoming partial sum. As a full weighted sum is acheived by partial sum additions, it will be integrated and triggered a spike in a spike NoC.

## Citation
The Shenjing work has been accepted by DATE 2020 conference.
> Bo Wang\*, Jun Zhou\*, Weng-Fai Wong and Li-Shiuan Peh, "Shenjing: a low power reconfigurable accelerator for neuromorphic computing with partial-sum and spike networks-on-chip", Design, Automation and Test in Europe Conference, March 2020.  
*\* Equally contributed*
